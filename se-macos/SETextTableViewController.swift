
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
    
    let virtualNewlines = false
    let virtualNewlineLength = Int64(12)
    
    var seFont: NSFont = NSFont(name: "Inconsolata", size: 16)!
    var savedCursorRow = 0
    var cursorView: NSView?
    var widestColumn: CGFloat = -1
    var pasteboard: NSPasteboard = NSPasteboard.general()
    
    func reload() {
//        let currentRow = Int(editor_buffer_get_cursor_row_virtual(buf!, virtualNewlineLength))
//        let currentCol = Int(editor_buffer_get_cursor_col_virtual(buf!, virtualNewlineLength))
//        Swift.print("current row: \(currentRow), col: \(currentCol)")
        
        self.tableView.reloadData()
        
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
        editor_buffer_save_file(buf!)
    }
    
    func seOpen(sender: NSMenuItem) {
        let dialog = NSOpenPanel();
        
        dialog.title = "Choose a file"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false

        if dialog.runModal() == NSModalResponseOK {
            let result = dialog.url // Pathname of the file
            
            if result != nil {
                let path = result!.path
                
                editor_buffer_open_file(buf!, path)
                
                widestColumn = -1
                
                reload()
            }
        }
    }
    
    func seChooseFont(sender: NSMenuItem) {
        let fontManager = NSFontManager.shared()
        let panel = fontManager.fontPanel(true)
        panel?.makeKeyAndOrderFront(sender)
    }
    
    func seIncreaseFontSize(sender: NSMenuItem) {
        self.seFont = NSFont(name: self.seFont.fontName, size: self.seFont.pointSize + 1)!
        recalculateTableRowHeight()
        self.reload()
    }
    
    func seDecreaseFontSIze(sender: NSMenuItem) {
        self.seFont = NSFont(name: self.seFont.fontName, size: self.seFont.pointSize - 1)!
        recalculateTableRowHeight()
        self.reload()
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
        
        buf = editor_buffer_create()
        
        undoSlider.max = 0;
        undoSlider.value = 0;
        undoSlider.delegate = self;
        
        globalUndoSlider.max = 0;
        globalUndoSlider.value = 0;
        globalUndoSlider.delegate = self;
        
        pasteboard.declareTypes([NSPasteboardTypeString], owner: nil)
        
        reload()
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
        
        let linesPerView = 4
        
        return (Int(lineCount) + linesPerView - 1) / linesPerView
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
//        Swift.print("row: \(row)")
        
        if buf == nil {
            return nil
        }
        
        let cell = self.tableView.make(withIdentifier: "Cell", owner: self) as! SETableCellView
        cell.controller = self
        cell.row = row
        
//        if cell.textField?.font != nil {
//            cell.textField!.font = self.seFont
//            cell.lineNumberView.font = self.seFont
//        }
        
        cell.reload()
        
        let width = cell.textField!.frame.width
        if width > widestColumn {
            widestColumn = width
            
            reload()
        }
        
        return cell
    }
    
    func recalculateTableRowHeight() {
        let view = self.tableView.view(atColumn: 0, row: 0, makeIfNecessary: true) as? SETableCellView
        view?.layoutSubtreeIfNeeded()
        
//        self.tableView.rowHeight = view!.textField!.frame.height * 4
        self.tableView.rowHeight = view!.row0.frame.height * 4
        
        self.tableView.reloadData()
    }
    
    override var acceptsFirstResponder: Bool { return true }
    
    func reloadTableRows(rows: [Int]) {
//        let max = tableView.numberOfRows
        
//        for row in rows {
//            if row < 0 { continue; }
//            if row > max - 1 { continue; }
//            
//            if let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? SETableCellView {
//                cell.reload()
//            }
//        }
        
//        tableView.reloadData(forRowIndexes: IndexSrows[0]..<max), columnIndexes: [0])
        
        reload()
    }
    
    override func keyDown(with event: NSEvent) {
        if let chars = event.characters {
            let currentRow: Int
            if virtualNewlines {
                currentRow = Int(editor_buffer_get_cursor_row_virtual(buf!, virtualNewlineLength))
            } else {
                currentRow = Int(editor_buffer_get_cursor_row(buf!))
            }
            
            if event.keyCode == 51 {
                // backspace
                let isSelection = editor_buffer_cursor_is_selection(buf!) == 1
                
                editor_buffer_delete(buf!)
                
                if isSelection {
                    reload()
                } else {
                    reloadTableRows(rows: [currentRow - 1, currentRow, currentRow + 1])
                }
            } else if event.keyCode == 123 {
                // left
                editor_buffer_set_cursor_is_selection(buf!, event.modifierFlags.contains(.shift) ?  1 : 0)
                
                if event.modifierFlags.contains(.command) {
                    if virtualNewlines {
                        let currentRow = editor_buffer_get_cursor_row_virtual(buf!, virtualNewlineLength)
                        editor_buffer_set_cursor_point_virtual(buf!, currentRow, 0, virtualNewlineLength)
                    } else {
                        let currentRow = editor_buffer_get_cursor_row(buf!)
                        editor_buffer_set_cursor_point(buf!, currentRow, 0)
                    }
                    
                    // todo(chad): handle cmd-shift-left to select to beginning of row
                } else {
                    editor_buffer_set_cursor_pos_relative(buf!, -1)
                }
                
                reloadTableRows(rows: [currentRow - 1, currentRow, currentRow + 1])
            } else if event.keyCode == 124 {
                // right
                editor_buffer_set_cursor_is_selection(buf!, event.modifierFlags.contains(.shift) ? 1 : 0)
                
                if event.modifierFlags.contains(.command) {
                    if virtualNewlines {
                        let currentRow = editor_buffer_get_cursor_row_virtual(buf!, virtualNewlineLength)
                        let currentRowLength = editor_buffer_get_line_length_virtual(buf!, currentRow, virtualNewlineLength)
                        
                        editor_buffer_set_cursor_point_virtual(buf!, currentRow, currentRowLength, virtualNewlineLength)
                    } else {
                        let currentRow = editor_buffer_get_cursor_row(buf!)
                        let currentRowLength = editor_buffer_get_line_length(buf!, currentRow)
                        
                        editor_buffer_set_cursor_point(buf!, currentRow, currentRowLength)
                    }
                    
                    // todo(chad): handle cmd-shift-left to select to beginning of row
                } else {
                    editor_buffer_set_cursor_pos_relative(buf!, 1)
                }
                
                reloadTableRows(rows: [currentRow - 1, currentRow, currentRow + 1])
            } else if event.keyCode == 125 {
                // down
                editor_buffer_set_cursor_is_selection(buf!, event.modifierFlags.contains(.shift) ? 1 : 0)
                
                if event.modifierFlags.contains(.command) {
                    if virtualNewlines {
                        let cursorRow = editor_buffer_get_line_count_virtual(buf!, virtualNewlineLength)
                        let cursorCol = editor_buffer_get_cursor_col_virtual(buf!, virtualNewlineLength)
                        
                        editor_buffer_set_cursor_point_virtual(buf!, cursorRow, cursorCol, virtualNewlineLength)
                    } else {
                        let cursorRow = editor_buffer_get_line_count(buf!)
                        let cursorCol = editor_buffer_get_cursor_col(buf!)
                        
                        editor_buffer_set_cursor_point(buf!, cursorRow, cursorCol)
                    }
                } else {
                    if virtualNewlines {
                        let cursorRow = editor_buffer_get_cursor_row_virtual(buf!, virtualNewlineLength)
                        let cursorCol = editor_buffer_get_cursor_col_virtual(buf!, virtualNewlineLength)
                        
                        editor_buffer_set_cursor_point_virtual(buf!, cursorRow + 1, cursorCol, virtualNewlineLength)
                    } else {
                        let cursorRow = editor_buffer_get_cursor_row(buf!)
                        let cursorCol = editor_buffer_get_cursor_col(buf!)
                        
                        editor_buffer_set_cursor_point(buf!, cursorRow + 1, cursorCol)
                    }
                }
                
                reloadTableRows(rows: [currentRow - 1, currentRow, currentRow + 1])
            } else if event.keyCode == 126 {
                // up
                editor_buffer_set_cursor_is_selection(buf!, event.modifierFlags.contains(.shift) ? 1 : 0)
                
                if event.modifierFlags.contains(.command) {
                    if virtualNewlines {
                        let cursorRow: Int64 = 0
                        let cursorCol = editor_buffer_get_cursor_col_virtual(buf!, virtualNewlineLength)
                        
                        editor_buffer_set_cursor_point_virtual(buf!, cursorRow, cursorCol, virtualNewlineLength)
                    } else {
                        let cursorRow: Int64 = 0
                        let cursorCol = editor_buffer_get_cursor_col(buf!)
                        
                        editor_buffer_set_cursor_point(buf!, cursorRow, cursorCol)
                    }
                } else {
                    if virtualNewlines {
                        let cursorRow = editor_buffer_get_cursor_row_virtual(buf!, virtualNewlineLength)
                        let cursorCol = editor_buffer_get_cursor_col_virtual(buf!, virtualNewlineLength)
                     
                        editor_buffer_set_cursor_point_virtual(buf!, cursorRow - 1, cursorCol, virtualNewlineLength)
                    } else {
                        let cursorRow = editor_buffer_get_cursor_row(buf!)
                        let cursorCol = editor_buffer_get_cursor_col(buf!)
                        
                        editor_buffer_set_cursor_point(buf!, cursorRow - 1, cursorCol)
                    }
                }

                reloadTableRows(rows: [currentRow - 1, currentRow, currentRow + 1])
            } else if event.keyCode == 36 {
                // enter
                editor_buffer_insert(buf!, "\n")
                
                reload()
            } else if event.keyCode == 6 && event.modifierFlags.contains(.command) {
                // z
                let undo_idx = editor_buffer_get_undo_index(buf!)
                if event.modifierFlags.contains(.shift) {
                    editor_buffer_undo(buf!, undo_idx + 1)
                } else {
                    editor_buffer_undo(buf!, undo_idx - 1)
                }
                reload()
            } else if event.keyCode == 5 && event.modifierFlags.contains(.command) {
                // g
                let undo_idx = editor_buffer_get_global_undo_index(buf!)
                if event.modifierFlags.contains(.shift) {
                    editor_buffer_global_undo(buf!, undo_idx + 1)
                } else {
                    editor_buffer_global_undo(buf!, undo_idx - 1)
                }
                reload()
            } else if event.keyCode == 8 && event.modifierFlags.contains(.command) {
                // c
                let startCharPos = editor_buffer_get_cursor_pos(buf!)
                let endCharPos = editor_buffer_get_cursor_selection_start_pos(buf!)
                
                // todo(chad): switch if they're backward
                let stringBuf = editor_buffer_get_text_between_characters(buf!, startCharPos, endCharPos)
                
                defer {
                    editor_buffer_free_buf(stringBuf)
                }
                
                let bufBytes = editor_buffer_get_buf_bytes(stringBuf)
                if bufBytes != nil {
                    let swiftString = String(cString: bufBytes!)
                    pasteboard.setString(swiftString, forType: NSPasteboardTypeString)
                }
            } else if event.keyCode == 9 && event.modifierFlags.contains(.command) {
                // v
                var clipboardItems: [String] = []
                for element in pasteboard.pasteboardItems! {
                    if let str = element.string(forType: "public.utf8-plain-text") {
                        clipboardItems.append(str)
                    }
                }
                if clipboardItems.count > 0 {
                    editor_buffer_insert(buf!, clipboardItems[0])   
                }
                
                reload()
            } else if event.keyCode == 0 && event.modifierFlags.contains(.command) {
                // a
                let charCount = editor_buffer_get_char_count(buf!)
                editor_buffer_set_cursor_pos(buf!, 0)
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_pos(buf!, charCount)
                
                reload()
            } else {
                // append chars
//                Swift.print(event.keyCode)
                
                let isSelection = editor_buffer_cursor_is_selection(buf!) == 1
                
                editor_buffer_insert(buf!, chars)
  
                if isSelection {
                    reload()
                } else {
                    reloadTableRows(rows: [currentRow - 1, currentRow, currentRow + 1])
                }
            }
        }
    }
    
    func ensureCursorVisible() {
        let currentRow: Int
        if virtualNewlines {
            currentRow = Int(editor_buffer_get_cursor_row_virtual(buf!, virtualNewlineLength))
        } else {
            currentRow = Int(editor_buffer_get_cursor_row(buf!))
        }

        if currentRow != savedCursorRow {
            savedCursorRow = currentRow
            tableView.scrollRowToVisible(currentRow)
        }
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
