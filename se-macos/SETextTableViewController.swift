
//
//  SETextTableViewController.swift
//  se-macos
//
//  Created by Chad Russell on 7/23/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SETextTableViewController : NSViewController, NSTableViewDataSource, NSTableViewDelegate, SESliderViewDelegate {
    
    @IBOutlet weak var tableView: SETableView!
    @IBOutlet weak var undoSlider: SESliderView!
    @IBOutlet weak var globalUndoSlider: SESliderView!
    
    var buf: editor_buffer_t?
    
    var virtualNewlines = false
    var virtualNewlineLength: Int64 = 80
    var seFont: NSFont = NSFont(name: "Inconsolata", size: 16)!
    var savedCursorRow = 0
    var cursorView: NSView?
    var widestColumn: CGFloat = -1
    var pasteboard = NSPasteboard.general
    var lineNumberColor = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
    var textColor = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
    var cursorColor = NSColor(red: 0.70, green: 0.70, blue: 0.99, alpha: 1)
    var selectionColor = NSColor(red: 0.70, green: 0.70, blue: 0.99, alpha: 1)
    var needsRowHeight = false
    
    func reload() {
        self.tableView.reloadData()
        reloadNoData()
    }
    
    func reloadNoData() {
        self.undoSlider.max = Int(editor_buffer_get_undo_size(buf!))
        self.undoSlider.value = Int(editor_buffer_get_undo_index(buf!))
        
        self.globalUndoSlider.max = Int(editor_buffer_get_global_undo_size(buf!))
        self.globalUndoSlider.value = Int(editor_buffer_get_global_undo_index(buf!))
        
        let column = tableView.tableColumns[0]
        if column.width != widestColumn {
            column.width = widestColumn + 100
        }
        
        ensureCursorVisible()
    }
    
    func seSave(sender: NSMenuItem) {
        if editor_buffer_has_file_path(buf!) == 0 {
            seSaveAs(sender: sender)
        } else {
            editor_buffer_save_file(buf!)
        }
    }
    
    func seSaveAs(sender: NSMenuItem) {
        let saveDialog = NSSavePanel();
        saveDialog.begin(completionHandler: { (result: NSApplication.ModalResponse) -> Void in
            if result == NSApplication.ModalResponse.OK {
                let filePath = saveDialog.url?.path
                editor_buffer_save_file_as(self.buf!, filePath)
            }
        })
    }
    
    func seOpen(sender: NSMenuItem) {
        let dialog = NSOpenPanel();
        
        dialog.title = "Choose a file"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = true
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false

        if dialog.runModal() == NSApplication.ModalResponse.OK {
            guard let result = dialog.url else { return }
        
            let path = result.path
            editor_buffer_open_file(buf!, 80, path)
            widestColumn = -1
            self.view.window?.title = result.lastPathComponent
            reload()
        }
    }
    
    func seChooseFont(sender: NSMenuItem) {
        let fontManager = NSFontManager.shared
        let panel = fontManager.fontPanel(true)
        panel?.makeKeyAndOrderFront(sender)
    }
    
    func seIncreaseFontSize(sender: NSMenuItem) {
        if self.seFont.pointSize < 72 {
            self.seFont = NSFont(name: self.seFont.fontName, size: self.seFont.pointSize + 1)!
            recalculateTableRowHeight()
        }
    }
    
    func seDecreaseFontSIze(sender: NSMenuItem) {
        if self.seFont.pointSize > 10 {
            self.seFont = NSFont(name: self.seFont.fontName, size: self.seFont.pointSize - 1)!
            recalculateTableRowHeight()
        }
    }
    
    override func changeFont(_ sender: Any?) {
        if let fontManager = sender as? NSFontManager {
            self.seFont = fontManager.convert(self.seFont)
            self.reload()
            
            recalculateTableRowHeight()
        } else {
            Swift.print("error: could not cast sender to an NSFontManager")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.controller = self
        tableView.tableColumns[0].width = 2000
        tableView.intercellSpacing = NSSize.zero
        
        buf = editor_buffer_create(80)
        
        undoSlider.max = 0;
        undoSlider.value = 0;
        undoSlider.delegate = self;
        
        globalUndoSlider.max = 0;
        globalUndoSlider.value = 0;
        globalUndoSlider.delegate = self;
        
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        
        loadConfigFile()
        
        var context = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = Unmanaged.passUnretained(self).toOpaque()
        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        let streamRef = FSEventStreamCreate(kCFAllocatorDefault, eventCallback, &context, ["/Users/chadrussell/.se_config.json"] as CFArray, lastEventId, 0, flags)!
        
        FSEventStreamScheduleWithRunLoop(streamRef, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(streamRef)
        
        reload()
    }
    
    let eventCallback: FSEventStreamCallback = { (stream: ConstFSEventStreamRef, clientCallbackInfo: UnsafeMutableRawPointer?, numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>, eventIds: UnsafePointer<FSEventStreamEventId>) in

        let controller: SETextTableViewController = unsafeBitCast(clientCallbackInfo, to: SETextTableViewController.self)
        let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]

        for index in 0..<numEvents {
            controller.loadConfigFile()
        }

        controller.lastEventId = eventIds[numEvents - 1]
    }
    var lastEventId: FSEventStreamEventId = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
    
    func loadConfigFile() {
        let configBuf = editor_buffer_create(100)
        editor_buffer_open_file(configBuf, 100, "/Users/chadrussell/.se_config.json")

        let charCount = editor_buffer_get_char_count(configBuf)
        let stringBuf = editor_buffer_get_text_between_characters(configBuf, 0, charCount)
        defer {
            editor_buffer_free_buf(stringBuf)
            editor_buffer_destroy(configBuf)
        }

        guard let bufBytes = editor_buffer_get_buf_bytes(stringBuf) else {
            Swift.print("could not load config file :(")
            return
        }

        let swiftString = String(cString: bufBytes)
        guard let data = swiftString.data(using: .utf8) else {
            Swift.print("could not load config file :(")
            return
        }
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let color = parseColor(json: json!, key: "line_number_color") {
                self.lineNumberColor = color
            }

            if let color = parseColor(json: json!, key: "text_color") {
                self.textColor = color
            }

            if let color = parseColor(json: json!, key: "background_color") {
                self.tableView.backgroundColor = color
            }

            if let color = parseColor(json: json!, key: "cursor_color") {
                self.cursorColor = color
            }

            if let color = parseColor(json: json!, key: "selection_color") {
                self.selectionColor = color
            }

            if let virtualNewlines = json!["virtual_newlines_enabled"] as? Bool {
                self.virtualNewlines = virtualNewlines
            }

            if let virtualNewlineLength = json!["virtual_newline_length"] as? Double {
                self.virtualNewlineLength = Int64(virtualNewlineLength)
            }

            if let fontName = json!["font_name"] as? String {
                if let font = NSFont(name: fontName, size: self.seFont.pointSize) {
                    self.seFont = font
                }
            }

            if let fontPointSize = json!["font_point_size"] as? Double {
                if let font = NSFont(name: self.seFont.fontName, size: CGFloat(fontPointSize)) {
                    self.seFont = font
                    recalculateTableRowHeight()
                }
            }
        }

        reload()
        recalculateTableRowHeight()
    }
    
    func parseColor(json: [String: Any], key: String) -> NSColor? {
        if let textColor = json[key] as? [String: Any] {
            let red = textColor["red"] as! Double
            let green = textColor["green"] as! Double
            let blue = textColor["blue"] as! Double
            
            if let alpha = textColor["alpha"] as? Double {
                return NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
            }
            
            return NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
        }
        
        return nil
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if buf == nil {
            return 0
        }
        
        let lineCount: Int64
        if virtualNewlines {
            lineCount = editor_buffer_get_line_count_virtual(buf!, virtualNewlineLength)
        } else {
            lineCount = editor_buffer_get_line_count(buf!)
        }
        
        let linesPerView = 8
        
        return (Int(lineCount) + linesPerView - 1) / linesPerView
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
//        Swift.print("row: \(row)")
        
        if buf == nil {
            return nil
        }
        
        let cell = self.tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Cell"), owner: self) as! SETableCellView
        cell.controller = self
        cell.row = row
        
        cell.reload()

        for rowN in [cell.row0, cell.row1, cell.row2, cell.row3, cell.row4, cell.row5, cell.row6, cell.row7] {
            let width = rowN!.textView.frame.width
            if width > self.widestColumn {
                self.widestColumn = width
                self.reload()
            }
        }

        if self.needsRowHeight {
            self.needsRowHeight = false
            self.tableView.rowHeight = cell.row0.textView.frame.height * 8
            self.widestColumn = -1
            reload()
        }
        
        return cell
    }
    
    func recalculateTableRowHeight() {
        if !self.needsRowHeight {
            self.needsRowHeight = true
            reload()
            return
        }
    }
    
    override var acceptsFirstResponder: Bool { return true }
    
    func reloadTableRows(lower: Int64, upper: Int64) {
        if virtualNewlines {
            reload()
            return
        }

        let rowIndexes = IndexSet(Int(lower) / 8 ... min(Int(upper) / 8, tableView.numberOfRows))
        tableView.reloadData(forRowIndexes: rowIndexes, columnIndexes: [0])

        reloadNoData()
    }
    
    override func keyDown(with event: NSEvent) {
        if let chars = event.characters {
            let currentRow: Int64
            let cursorCount = editor_buffer_get_cursor_count(buf!)
            if cursorCount > 1 {
                currentRow = 0
            } else if virtualNewlines {
                currentRow = editor_buffer_get_cursor_row_virtual(buf!, 0, virtualNewlineLength)
            } else {
                currentRow = editor_buffer_get_cursor_row(buf!, 0)
            }
            
            let isMultiCursorOrSelection = (cursorCount != 1) || (editor_buffer_cursor_is_selection(buf!, 0) == 1)
            
            if event.keyCode == 51 {
                // backspace
                editor_buffer_delete(buf!)
                
                if isMultiCursorOrSelection {
                    reload()
                } else {
                    reloadTableRows(lower: currentRow - 1, upper: Int64.max)
                }
            } else if event.keyCode == 123 {
                // left
                editor_buffer_set_cursor_is_selection(buf!, event.modifierFlags.contains(NSEvent.ModifierFlags.shift) ?  1 : 0)
                
                if event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
                    if virtualNewlines {
                        editor_buffer_set_cursor_point_to_start_of_line_virtual(buf!, virtualNewlineLength)
                    } else {
                        editor_buffer_set_cursor_point_to_start_of_line(buf!)
                    }
                } else {
                    editor_buffer_set_cursor_pos_relative(buf!, -1)
                }
                
                if isMultiCursorOrSelection {
                    reload()
                } else {
                    reloadTableRows(lower: currentRow - 1, upper: currentRow + 1)
                }
            } else if event.keyCode == 124 {
                // right
                editor_buffer_set_cursor_is_selection(buf!, event.modifierFlags.contains(NSEvent.ModifierFlags.shift) ? 1 : 0)
                
                if event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
                    if virtualNewlines {
                        editor_buffer_set_cursor_point_to_end_of_line_virtual(buf!, virtualNewlineLength)
                    } else {
                        editor_buffer_set_cursor_point_to_end_of_line(buf!)
                    }
                } else {
                    editor_buffer_set_cursor_pos_relative(buf!, 1)
                }
            
                if isMultiCursorOrSelection {
                    reload()
                } else {
                    reloadTableRows(lower: currentRow - 1, upper: currentRow + 1)
                }
            } else if event.keyCode == 125 {
                // down
                editor_buffer_set_cursor_is_selection(buf!, event.modifierFlags.contains(NSEvent.ModifierFlags.shift) ? 1 : 0)
                
                if event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
                    let fileLength = editor_buffer_get_char_count(buf!)
                    editor_buffer_set_cursor_pos(buf!, fileLength)
                } else {
                    if virtualNewlines {
                        for i in 0..<editor_buffer_get_cursor_count(buf!) {
                            let cursorCol = editor_buffer_get_cursor_col_virtual(buf!, i, virtualNewlineLength)
                            let cursorRow = editor_buffer_get_cursor_row_virtual(buf!, i, virtualNewlineLength)
                            editor_buffer_set_cursor_point_virtual_for_cursor_index(buf!, i, cursorRow + 1, cursorCol, virtualNewlineLength)
                        }
                    } else {
                        for i in 0..<editor_buffer_get_cursor_count(buf!) {
                            let cursorRow = editor_buffer_get_cursor_row(buf!, i)
                            let cursorCol = editor_buffer_get_cursor_col(buf!, i)
                            editor_buffer_set_cursor_point_for_cursor_index(buf!, i, cursorRow + 1, cursorCol)
                        }
                    }
                    
                    sort_and_merge_cursors(buf!)
                }
                
                if isMultiCursorOrSelection {
                    reload()
                } else {
                    reloadTableRows(lower: currentRow - 1, upper: currentRow + 1)
                }
            } else if event.keyCode == 126 {
                // up
                editor_buffer_set_cursor_is_selection(buf!, event.modifierFlags.contains(NSEvent.ModifierFlags.shift) ? 1 : 0)
                
                if event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
                    editor_buffer_set_cursor_pos(buf!, 0)
                } else {
                    if virtualNewlines {
                        for i in 0..<editor_buffer_get_cursor_count(buf!) {
                            let cursorCol = editor_buffer_get_cursor_col_virtual(buf!, i, virtualNewlineLength)
                            let cursorRow = editor_buffer_get_cursor_row_virtual(buf!, i, virtualNewlineLength)
                            editor_buffer_set_cursor_point_virtual_for_cursor_index(buf!, i, cursorRow - 1, cursorCol, virtualNewlineLength)
                        }
                    } else {
                        for i in 0..<editor_buffer_get_cursor_count(buf!) {
                            let cursorRow = editor_buffer_get_cursor_row(buf!, i)
                            let cursorCol = editor_buffer_get_cursor_col(buf!, i)
                            editor_buffer_set_cursor_point_for_cursor_index(buf!, i, cursorRow - 1, cursorCol)
                        }
                    }
                    
                    sort_and_merge_cursors(buf!)
                }

                if isMultiCursorOrSelection {
                    reload()
                } else {
                    reloadTableRows(lower: currentRow - 1, upper: currentRow + 1)
                }
            } else if event.keyCode == 36 {
                // enter
                editor_buffer_insert(buf!, "\n")
                
                reload()
            } else if event.keyCode == 6 && event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
                // z
                let undo_idx = editor_buffer_get_undo_index(buf!)
                if event.modifierFlags.contains(NSEvent.ModifierFlags.shift) {
                    editor_buffer_undo(buf!, undo_idx + 1)
                } else {
                    editor_buffer_undo(buf!, undo_idx - 1)
                }
                reload()
            } else if event.keyCode == 5 && event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
                // g
                let undo_idx = editor_buffer_get_global_undo_index(buf!)
                if event.modifierFlags.contains(NSEvent.ModifierFlags.shift) {
                    editor_buffer_global_undo(buf!, undo_idx + 1)
                } else {
                    editor_buffer_global_undo(buf!, undo_idx - 1)
                }
                reload()
            } else if event.keyCode == 8 && event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
                // c
                if event.modifierFlags.contains(NSEvent.ModifierFlags.shift) {
                    loadConfigFile()
                    return
                }

                if cursorCount > 1 { return }
                
                var startCharPos = editor_buffer_get_cursor_pos(buf!, 0)
                var endCharPos = editor_buffer_get_cursor_selection_start_pos(buf!, 0)
                
                if startCharPos > endCharPos {
                    let tmp = startCharPos
                    startCharPos = endCharPos
                    endCharPos = tmp
                }
                
                let stringBuf = editor_buffer_get_text_between_characters(buf!, startCharPos, endCharPos)
                
                defer {
                    editor_buffer_free_buf(stringBuf)
                }
                
                let bufBytes = editor_buffer_get_buf_bytes(stringBuf)
                if bufBytes != nil {
                    let swiftString = String(cString: bufBytes!)
                    pasteboard.setString(swiftString, forType: NSPasteboard.PasteboardType(rawValue: "public.utf8-plain-text"))
                }
            } else if event.keyCode == 9 && event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
                // v
                var clipboardItems: [String] = []
                for element in pasteboard.pasteboardItems! {
                    if let str = element.string(forType: NSPasteboard.PasteboardType(rawValue: "public.utf8-plain-text")) {
                        clipboardItems.append(str)
                    }
                }
                if clipboardItems.count > 0 {
                    editor_buffer_insert(buf!, clipboardItems[0])   
                }
                
                reload()
            } else if event.keyCode == 0 && event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
                // a
                let charCount = editor_buffer_get_char_count(buf!)
                editor_buffer_set_cursor_pos(buf!, 0)
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_pos(buf!, charCount)
                
                reload()
            } else {
                // append chars
//                Swift.print(event.keyCode)
                
                editor_buffer_insert(buf!, chars)
  
                if isMultiCursorOrSelection {
                    reload()
                } else {
                    reloadTableRows(lower: currentRow, upper: currentRow)
                }
            }
        }
    }
    
    func ensureCursorVisible() {
        let cursorCount = editor_buffer_get_cursor_count(buf!)
        if cursorCount > 1 { return }
        
        let currentRow: Int
        if virtualNewlines {
            currentRow = Int(editor_buffer_get_cursor_row_virtual(buf!, 0, virtualNewlineLength))
        } else {
            currentRow = Int(editor_buffer_get_cursor_row(buf!, 0))
        }

        let tableViewRow = currentRow / 8
        
        if tableViewRow != savedCursorRow {
            savedCursorRow = tableViewRow
            tableView.scrollRowToVisible(tableViewRow)
        }
        
//        if self.cursorView != nil {
//            let visibleRect = tableView.visibleRect
//            let cursorRect = tableView.convert(self.cursorView!.frame, from: self.cursorView!)
//
//            print(visibleRect, cursorRect)
//
//            if (!visibleRect.contains(cursorRect)) {
//                tableView.scrollToVisible(cursorRect)
//            }
//        }
    }
    
    func valueChanged(_ sliderView: SESliderView) {
        if sliderView == undoSlider {
            editor_buffer_undo(buf!, Int64(sliderView.savedValue))
            reload()
        } else if sliderView == globalUndoSlider {
            editor_buffer_global_undo(buf!, Int64(sliderView.savedValue))
            reload()
        }
    }
}
