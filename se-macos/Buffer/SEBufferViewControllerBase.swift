//
//  SEBufferViewControllerBase.swift
//  se-macos
//
//  Created by Chad Russell on 8/28/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SEBufferViewControllerBase: NSViewController, SEBufferDelegate {
    @IBOutlet var editorView: SEEditorView!
    
    var preferences = SEEditorPreferences()
    var mode = SEMode.insert
    var buf: editor_buffer_t? = editor_buffer_create(80)
    let pasteboard = NSPasteboard.general
    var commandStack = [NSEvent]()
    
    var lineWidthConstraint: NSLayoutConstraint? { return nil }
    
    // handles autoscrolling when a drag gesture exists the window
    var dragTimer: Timer?
    var dragEvent: NSEvent?
    
    override func viewDidLoad() {
        self.editorView.delegate = self
        
        self.view.wantsLayer = true
        
        loadConfigFile()
        watchConfigFile()
    }
    
    override func viewWillDisappear() {
        editor_buffer_destroy(buf!)
    }
    
    func watchConfigFile() {
        var context = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = Unmanaged.passUnretained(self).toOpaque()
        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        let streamRef = FSEventStreamCreate(kCFAllocatorDefault, eventCallback, &context, ["/Users/chadrussell/.se_config.json"] as CFArray, lastEventId, 0, flags)!
        
        FSEventStreamScheduleWithRunLoop(streamRef, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(streamRef)
    }
    
    let eventCallback: FSEventStreamCallback = { (stream: ConstFSEventStreamRef, clientCallbackInfo: UnsafeMutableRawPointer?, numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>, eventIds: UnsafePointer<FSEventStreamEventId>) in
        
        let controller: SEBufferViewController = unsafeBitCast(clientCallbackInfo, to: SEBufferViewController.self)
        let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
        
        if numEvents > 0 {
            controller.loadConfigFile()
        }
        
        controller.lastEventId = eventIds[numEvents - 1]
    }
    var lastEventId: FSEventStreamEventId = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
    
    func reload() {
        self.editorView.needsDisplay = true
    }
    
    func drawLastLine() {
        self.editorView.cursorRects = []
        let cursorCount = editor_buffer_get_cursor_count(buf!)
        let row: Int64
        if preferences.virtualNewlines {
            row = editor_buffer_get_cursor_row_virtual(buf!, cursorCount - 1, preferences.virtualNewlineLength)
        } else {
            row = editor_buffer_get_cursor_row(buf!, cursorCount - 1)
        }
        self.editorView.drawLine(line: row, scrollToCursor: true)
        
        if !self.editorView.cursorRects.isEmpty {
            let cursorRect = self.editorView.cursorRects.reduce(self.editorView.cursorRects[0], { a, b in a.union(b) })
            let outsetRect = cursorRect.insetBy(dx: -5, dy: -5)
            if !self.editorView.visibleRect.contains(cursorRect) {
                self.editorView.scrollToVisible(outsetRect)
            }
        }
    }
    
    func handleKeyDown(with event: NSEvent) {
        switch mode {
        case .insert: handleKeyDownForInsertMode(event)
        case .normal: handleKeyDownForNormalMode(event)
        }
    }
    
    func handleKeyDownForInsertMode(_ event: NSEvent) {
        if event.keyCode == 123 {
            // left
            editor_buffer_set_cursor_is_selection(buf!, event.modifierFlags.contains(.shift) ? 1 : 0)
            
            if event.modifierFlags.contains(.command) {
                if preferences.virtualNewlines {
                    editor_buffer_set_cursor_point_to_start_of_line_virtual(buf!, preferences.virtualNewlineLength)
                } else {
                    editor_buffer_set_cursor_point_to_start_of_line(buf!)
                }
            } else if event.modifierFlags.contains(.option) {
                editor_buffer_set_cursor_point_to_start_of_previous_word(buf!)
            } else {
                editor_buffer_set_cursor_pos_relative(buf!, -1)
            }
        } else if event.keyCode == 124 {
            // right
            editor_buffer_set_cursor_is_selection(buf!, event.modifierFlags.contains(.shift) ? 1 : 0)
            
            if event.modifierFlags.contains(.command) {
                if preferences.virtualNewlines {
                    editor_buffer_set_cursor_point_to_end_of_line_virtual(buf!, preferences.virtualNewlineLength)
                } else {
                    editor_buffer_set_cursor_point_to_end_of_line(buf!)
                }
            } else if event.modifierFlags.contains(.option) {
                editor_buffer_set_cursor_point_to_start_of_next_word(buf!)
            } else {
                editor_buffer_set_cursor_pos_relative(buf!, 1)
            }
        } else if event.keyCode == 125 {
            // down
            editor_buffer_set_cursor_is_selection(buf!, event.modifierFlags.contains(.shift) ? 1 : 0)
            
            if event.modifierFlags.contains(.command) {
                let charCount = editor_buffer_get_char_count(buf!)
                editor_buffer_set_cursor_pos(buf!, charCount)
            } else if event.modifierFlags.contains(.option) {
                for i in 0 ..< editor_buffer_get_cursor_count(buf!) {
                    if preferences.virtualNewlines {
                        var cursorRow = editor_buffer_get_cursor_row_virtual(buf!, i, preferences.virtualNewlineLength) + 1
                        let lineCount = editor_buffer_get_line_count_virtual(buf!, preferences.virtualNewlineLength)
                        while cursorRow < lineCount && editor_buffer_get_line_length_virtual(buf!, cursorRow, preferences.virtualNewlineLength) > 0 {
                            cursorRow += 1
                        }
                        editor_buffer_set_cursor_point_virtual_for_cursor_index(buf!, i, cursorRow, 0, preferences.virtualNewlineLength)
                    } else {
                        var cursorRow = editor_buffer_get_cursor_row(buf!, i) + 1
                        let lineCount = editor_buffer_get_line_count(buf!)
                        while cursorRow < lineCount && editor_buffer_get_line_length(buf!, cursorRow) > 0 {
                            cursorRow += 1
                        }
                        editor_buffer_set_cursor_point_for_cursor_index(buf!, i, cursorRow, 0)
                    }
                }
            } else {
                // todo(chad): make an editor_buffer_set_cursor_point_row_relative and virtual counterpart
                for i in 0..<editor_buffer_get_cursor_count(buf!) {
                    if preferences.virtualNewlines {
                        let cursorRow = editor_buffer_get_cursor_row_virtual(buf!, i, preferences.virtualNewlineLength)
                        let cursorCol = editor_buffer_get_cursor_col_virtual(buf!, i, preferences.virtualNewlineLength)
                        editor_buffer_set_cursor_point_virtual_for_cursor_index(buf!, i, cursorRow + 1, cursorCol, preferences.virtualNewlineLength)
                    } else {
                        let cursorRow = editor_buffer_get_cursor_row(buf!, i)
                        let cursorCol = editor_buffer_get_cursor_col(buf!, i)
                        editor_buffer_set_cursor_point_for_cursor_index(buf!, i, cursorRow + 1, cursorCol)
                    }
                }
            }
        } else if event.keyCode == 126 {
            // up
            editor_buffer_set_cursor_is_selection(buf!, event.modifierFlags.contains(.shift) ? 1 : 0)
            
            if event.modifierFlags.contains(.command) {
                editor_buffer_set_cursor_pos(buf!, 0)
            } else if event.modifierFlags.contains(.option) {
                for i in 0 ..< editor_buffer_get_cursor_count(buf!) {
                    if preferences.virtualNewlines {
                        var cursorRow = editor_buffer_get_cursor_row_virtual(buf!, i, preferences.virtualNewlineLength) - 1
                        while cursorRow > 0 && editor_buffer_get_line_length_virtual(buf!, cursorRow, preferences.virtualNewlineLength) > 0 {
                            cursorRow -= 1
                        }
                        editor_buffer_set_cursor_point_virtual_for_cursor_index(buf!, i, cursorRow, 0, preferences.virtualNewlineLength)
                    } else {
                        var cursorRow = editor_buffer_get_cursor_row(buf!, i) - 1
                        while cursorRow > 0 && editor_buffer_get_line_length(buf!, cursorRow) > 0 {
                            cursorRow -= 1
                        }
                        editor_buffer_set_cursor_point_for_cursor_index(buf!, i, cursorRow, 0)
                    }
                }
            } else {
                // todo(chad): make an editor_buffer_set_cursor_point_row_relative and virtual counterpart
                for i in 0..<editor_buffer_get_cursor_count(buf!) {
                    if preferences.virtualNewlines {
                        let cursorRow = editor_buffer_get_cursor_row_virtual(buf!, i, preferences.virtualNewlineLength)
                        let cursorCol = editor_buffer_get_cursor_col_virtual(buf!, i, preferences.virtualNewlineLength)
                        editor_buffer_set_cursor_point_virtual_for_cursor_index(buf!, i, cursorRow - 1, cursorCol, preferences.virtualNewlineLength)
                    } else {
                        let cursorRow = editor_buffer_get_cursor_row(buf!, i)
                        let cursorCol = editor_buffer_get_cursor_col(buf!, i)
                        editor_buffer_set_cursor_point_for_cursor_index(buf!, i, cursorRow - 1, cursorCol)
                    }
                }
            }
        } else if event.keyCode == 36 {
            // enter
            editor_buffer_insert(buf!, "\n")
            editor_buffer_set_cursor_is_selection(buf!, 0)
        } else if event.keyCode == 51 {
            // backspace
            if editor_buffer_get_char_count(buf!) == 0 { return }
            
            if event.modifierFlags.contains(.command) && editor_buffer_cursor_is_selection(buf!, 0) == 0 {
                editor_buffer_set_cursor_is_selection(buf!, 1)
                
                if preferences.virtualNewlines {
                    editor_buffer_set_cursor_point_to_start_of_line_virtual(buf!, preferences.virtualNewlineLength)
                } else {
                    editor_buffer_set_cursor_point_to_start_of_line(buf!)
                }
                
                editor_buffer_delete(buf!)
                editor_buffer_set_cursor_is_selection(buf!, 0)
            } else if event.modifierFlags.contains(.option) && editor_buffer_cursor_is_selection(buf!, 0) == 0 {
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_point_to_start_of_previous_word(buf!)
                editor_buffer_delete(buf!)
                editor_buffer_set_cursor_is_selection(buf!, 0)
            } else {
                editor_buffer_delete(buf!)
                editor_buffer_set_cursor_is_selection(buf!, 0)
            }
        } else if event.keyCode == 8 && event.modifierFlags.contains(.command) {
            // c
            if event.modifierFlags.contains(.shift) && event.modifierFlags.contains(.command) {
                editor_buffer_open_file(buf!, UInt32(preferences.virtualNewlineLength), "/Users/chadrussell/.se_config.json")
            } else {
                copySelection()
            }
        } else if event.keyCode == 9 && event.modifierFlags.contains(.command) {
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
            
            editor_buffer_set_cursor_is_selection(buf!, 0)
        } else if event.keyCode == 0 && event.modifierFlags.contains(.command) {
            // a
            editor_buffer_set_cursor_is_selection(buf!, 0)
            editor_buffer_set_cursor_pos(buf!, 0)
            editor_buffer_set_cursor_is_selection(buf!, 1)
            editor_buffer_set_cursor_pos(buf!, editor_buffer_get_char_count(buf!))
        } else if event.keyCode == 6 && event.modifierFlags.contains(.command) {
            // z
            editor_buffer_set_cursor_is_selection(buf!, 0)
            let undo_idx = editor_buffer_get_undo_index(buf!)
            if event.modifierFlags.contains(.shift) {
                editor_buffer_undo(buf!, undo_idx + 1)
            } else {
                editor_buffer_undo(buf!, undo_idx - 1)
            }
        } else if event.keyCode == 5 && event.modifierFlags.contains(.command) {
            // g
            editor_buffer_set_cursor_is_selection(buf!, 0)
            let undo_idx = editor_buffer_get_global_undo_index(buf!)
            if event.modifierFlags.contains(.shift) {
                editor_buffer_global_undo(buf!, undo_idx + 1)
            } else {
                editor_buffer_global_undo(buf!, undo_idx - 1)
            }
        } else if event.keyCode == 7 && event.modifierFlags.contains(.command) {
            // x
            copySelection()
            editor_buffer_delete(buf!)
            editor_buffer_set_cursor_is_selection(buf!, 0)
        } else if event.keyCode == 33 && event.modifierFlags.contains(.control) {
            // ctrl + [ (vim-style escape into normal mode)
            mode = .normal
        } else if event.keyCode == 53 {
            // esc
            mode = .normal
        } else if let chars = event.characters {
            //            Swift.print(event.keyCode)
            
            editor_buffer_insert(buf!, chars)
            editor_buffer_set_cursor_is_selection(buf!, 0)
        }
        
        drawLastLine()
        sort_and_merge_cursors(buf!)
        reload()
    }
    
    func handleKeyDownForNormalMode(_ event: NSEvent) {
        if event.keyCode == 34 {
            // i
            if event.modifierFlags.contains(.shift) {
                if preferences.virtualNewlines {
                    editor_buffer_set_cursor_point_to_start_of_line_virtual(buf!, preferences.virtualNewlineLength)
                } else {
                    editor_buffer_set_cursor_point_to_start_of_line(buf!)
                }
            } else {
                for cursorIdx in 0 ..< editor_buffer_get_cursor_count(buf!) {
                    if editor_buffer_cursor_is_selection(buf!, cursorIdx) == 1 {
                        let cursorPos = editor_buffer_get_cursor_pos(buf!, cursorIdx)
                        let cursorSelectionPos = editor_buffer_get_cursor_selection_start_pos(buf!, cursorIdx)
                        editor_buffer_set_cursor_pos(buf!, min(cursorPos, cursorSelectionPos))
                    }
                }
            }
            
            editor_buffer_set_cursor_is_selection(buf!, 0)
            mode = .insert
        } else if event.keyCode == 0 {
            // a
            if event.modifierFlags.contains(.shift) {
                if preferences.virtualNewlines {
                    editor_buffer_set_cursor_point_to_end_of_line_virtual(buf!, preferences.virtualNewlineLength)
                } else {
                    editor_buffer_set_cursor_point_to_end_of_line(buf!)
                }
            } else {
                for cursorIdx in 0 ..< editor_buffer_get_cursor_count(buf!) {
                    if editor_buffer_cursor_is_selection(buf!, cursorIdx) == 1 {
                        let cursorPos = editor_buffer_get_cursor_pos(buf!, cursorIdx)
                        let cursorSelectionPos = editor_buffer_get_cursor_selection_start_pos(buf!, cursorIdx)
                        editor_buffer_set_cursor_pos(buf!, max(cursorPos + 1, cursorSelectionPos))
                    } else {
                        editor_buffer_set_cursor_pos(buf!, editor_buffer_get_cursor_pos(buf!, cursorIdx) + 1)
                    }
                }
            }
            
            editor_buffer_set_cursor_is_selection(buf!, 0)
            mode = .insert
        } else if event.keyCode == 4 {
            // h
            editor_buffer_set_cursor_pos_relative(buf!, -1)
        } else if event.keyCode == 38 {
            // j
            // todo(chad): make an editor_buffer_set_cursor_point_row_relative and virtual counterpart
            for i in 0..<editor_buffer_get_cursor_count(buf!) {
                if preferences.virtualNewlines {
                    let cursorRow = editor_buffer_get_cursor_row_virtual(buf!, i, preferences.virtualNewlineLength)
                    let cursorCol = editor_buffer_get_cursor_col_virtual(buf!, i, preferences.virtualNewlineLength)
                    editor_buffer_set_cursor_point_virtual_for_cursor_index(buf!, i, cursorRow + 1, cursorCol, preferences.virtualNewlineLength)
                } else {
                    let cursorRow = editor_buffer_get_cursor_row(buf!, i)
                    let cursorCol = editor_buffer_get_cursor_col(buf!, i)
                    editor_buffer_set_cursor_point_for_cursor_index(buf!, i, cursorRow + 1, cursorCol)
                }
            }
        } else if event.keyCode == 40 {
            // k
            // todo(chad): make an editor_buffer_set_cursor_point_row_relative and virtual counterpart
            for i in 0..<editor_buffer_get_cursor_count(buf!) {
                if preferences.virtualNewlines {
                    let cursorRow = editor_buffer_get_cursor_row_virtual(buf!, i, preferences.virtualNewlineLength)
                    let cursorCol = editor_buffer_get_cursor_col_virtual(buf!, i, preferences.virtualNewlineLength)
                    editor_buffer_set_cursor_point_virtual_for_cursor_index(buf!, i, cursorRow - 1, cursorCol, preferences.virtualNewlineLength)
                } else {
                    let cursorRow = editor_buffer_get_cursor_row(buf!, i)
                    let cursorCol = editor_buffer_get_cursor_col(buf!, i)
                    editor_buffer_set_cursor_point_for_cursor_index(buf!, i, cursorRow - 1, cursorCol)
                }
            }
        } else if event.keyCode == 37 {
            // l
            editor_buffer_set_cursor_pos_relative(buf!, 1)
        } else if event.keyCode == 9 {
            // v
            if event.modifierFlags.contains(.shift) {
                editor_buffer_set_cursor_point_to_start_of_line(buf!)
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_point_to_end_of_line(buf!)
            } else {
                editor_buffer_set_cursor_is_selection(buf!, 1)
            }
        } else if event.keyCode == 2 {
            // d
            if event.modifierFlags.contains(.shift) {
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_point_to_end_of_line(buf!)
            }
            copySelection()
            editor_buffer_delete(buf!)
            editor_buffer_set_cursor_is_selection(buf!, 0)
        } else if event.keyCode == 13 {
            // w
            editor_buffer_set_cursor_point_to_start_of_next_word(buf!)
        } else if event.keyCode == 14 {
            // e
            editor_buffer_set_cursor_point_to_end_of_current_word(buf!)
        } else if event.keyCode == 11 {
            // b
            editor_buffer_set_cursor_point_to_start_of_previous_word(buf!)
        } else if event.keyCode == 21 && event.modifierFlags.contains(.shift) {
            // $ (end-of-line)
            if preferences.virtualNewlines {
                editor_buffer_set_cursor_point_to_end_of_line_virtual(buf!, preferences.virtualNewlineLength)
            } else {
                editor_buffer_set_cursor_point_to_end_of_line(buf!)
            }
        } else if event.keyCode == 22 && event.modifierFlags.contains(.shift) {
            // ^ (start-of-line)
            if preferences.virtualNewlines {
                editor_buffer_set_cursor_point_to_start_of_line_virtual(buf!, preferences.virtualNewlineLength)
            } else {
                editor_buffer_set_cursor_point_to_start_of_line(buf!)
            }
        } else if event.keyCode == 16 {
            // y
            copySelection()
        } else if event.keyCode == 7 {
            // x
            var cursorIsSelection = false
            for cursorIdx in 0 ..< editor_buffer_get_cursor_count(buf!) {
                if !cursorIsSelection && editor_buffer_cursor_is_selection(buf!, cursorIdx) == 1 {
                    cursorIsSelection = true
                    
                    copySelection()
                    editor_buffer_delete(buf!)
                    editor_buffer_set_cursor_is_selection(buf!, 0)
                }
            }
            if !cursorIsSelection {
                editor_buffer_set_cursor_pos_relative(buf!, 1)
                editor_buffer_delete(buf!)
            }
        } else if event.keyCode == 31 {
            // o
            if event.modifierFlags.contains(.shift) {
                for i in 0..<editor_buffer_get_cursor_count(buf!) {
                    if preferences.virtualNewlines {
                        let cursorRow = editor_buffer_get_cursor_row_virtual(buf!, i, preferences.virtualNewlineLength)
                        let cursorCol = editor_buffer_get_cursor_col_virtual(buf!, i, preferences.virtualNewlineLength)
                        editor_buffer_set_cursor_point_virtual_for_cursor_index(buf!, i, cursorRow - 1, cursorCol, preferences.virtualNewlineLength)
                    } else {
                        let cursorRow = editor_buffer_get_cursor_row(buf!, i)
                        let cursorCol = editor_buffer_get_cursor_col(buf!, i)
                        editor_buffer_set_cursor_point_for_cursor_index(buf!, i, cursorRow - 1, cursorCol)
                    }
                }
            }
            
            if preferences.virtualNewlines {
                editor_buffer_set_cursor_point_to_end_of_line_virtual(buf!, preferences.virtualNewlineLength)
                editor_buffer_insert(buf!, "\n")
            } else {
                editor_buffer_set_cursor_point_to_end_of_line(buf!)
                editor_buffer_insert(buf!, "\n")
            }
            
            mode = .insert
        } else if event.keyCode == 53 {
            // esc
            editor_buffer_set_cursor_is_selection(buf!, 0)
        } else if event.keyCode == 35 {
            // p
            var clipboardItems: [String] = []
            for element in pasteboard.pasteboardItems! {
                if let str = element.string(forType: NSPasteboard.PasteboardType(rawValue: "public.utf8-plain-text")) {
                    clipboardItems.append(str)
                }
            }
            if clipboardItems.count > 0 {
                editor_buffer_insert(buf!, clipboardItems[0])
            }
            
            editor_buffer_set_cursor_is_selection(buf!, 0)
        } else if event.keyCode == 8 {
            // c
            if event.modifierFlags.contains(.shift) {
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_point_to_end_of_line(buf!)
            }
            copySelection()
            editor_buffer_delete(buf!)
            editor_buffer_set_cursor_is_selection(buf!, 0)
            mode = .insert
        } else if event.keyCode == 32 {
            // u
            editor_buffer_set_cursor_is_selection(buf!, 0)
            if event.modifierFlags.contains(.shift) {
                let undo_idx = editor_buffer_get_global_undo_index(buf!)
                editor_buffer_global_undo(buf!, undo_idx - 1)
            } else {
                let undo_idx = editor_buffer_get_undo_index(buf!)
                editor_buffer_undo(buf!, undo_idx - 1)
            }
        } else if event.keyCode == 15 {
            // r
            if event.modifierFlags.contains(.control) {
                editor_buffer_set_cursor_is_selection(buf!, 0)
                if event.modifierFlags.contains(.shift) {
                    let undo_idx = editor_buffer_get_global_undo_index(buf!)
                    editor_buffer_global_undo(buf!, undo_idx + 1)
                } else {
                    let undo_idx = editor_buffer_get_undo_index(buf!)
                    editor_buffer_undo(buf!, undo_idx + 1)
                }
            }
        }
        
        drawLastLine()
        sort_and_merge_cursors(buf!)
        reload()
    }
    
    func copySelection() {
        var swiftString = ""
        let cursorCount = editor_buffer_get_cursor_count(buf!)
        for i in 0 ..< cursorCount {
            var startCharPos = editor_buffer_get_cursor_pos(buf!, i)
            var endCharPos = editor_buffer_get_cursor_selection_start_pos(buf!, i)
            
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
                swiftString.append(String(cString: bufBytes!))
            }
        }
        
        if swiftString != "" {
            pasteboard.clearContents()
            pasteboard.setString(swiftString, forType: NSPasteboard.PasteboardType(rawValue: "public.utf8-plain-text"))
        }
    }
    
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
            if let virtualNewlines = json!["virtual_newlines_enabled"] as? Bool {
                preferences.virtualNewlines = virtualNewlines
            }
            
            if let virtualNewlineLength = json!["virtual_newline_length"] as? Double {
                preferences.virtualNewlineLength = Int64(virtualNewlineLength)
            }
            
            if let cursorBlink = json!["cursor_blink"] as? Bool {
                preferences.cursorBlink = cursorBlink
            }
            
            if let cursorBlinkPeriod = json!["cursor_blink_period"] as? Double {
                preferences.cursorBlinkPeriod = cursorBlinkPeriod
            }
            
            if let fontName = json!["font_name"] as? String {
                if let font = NSFont(name: fontName, size: preferences.editorFont.pointSize) {
                    preferences.editorFont = font
                }
            }
            
            if let fontPointSize = json!["font_point_size"] as? Double {
                if let font = NSFont(name: preferences.editorFont.fontName, size: CGFloat(fontPointSize)) {
                    preferences.editorFont = font
                }
            }
            
            if let showGutter = json!["show_gutter"] as? Bool {
                preferences.showGutter = showGutter
            }
            
            if let color = parseColor(json: json!, key: "gutter_text_color") {
                preferences.gutterTextColor = color
            }
            
            if let color = parseColor(json: json!, key: "editor_text_color") {
                preferences.editorTextColor = color
            }
            
            if let color = parseColor(json: json!, key: "gutter_background_color") {
                preferences.gutterBackgroundColor = color
            }
            
            if let color = parseColor(json: json!, key: "editor_background_color") {
                preferences.editorBackgroundColor = color
            }
            
            if let color = parseColor(json: json!, key: "cursor_color") {
                preferences.cursorColor = color
            }
            
            if let color = parseColor(json: json!, key: "selection_color") {
                preferences.selectionColor = color
            }
            
        }
        
        reload()
    }
    
    func parseColor(json: [String: Any], key: String) -> NSColor? {
        if let color = json[key] as? [String: Any] {
            let red = color["red"] as! Double
            let green = color["green"] as! Double
            let blue = color["blue"] as! Double
            
            if let alpha = color["alpha"] as? Double {
                return NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
            }
            
            return NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
        }
        
        return nil
    }
    
    func handleMouseDown(with theEvent: NSEvent) {
        Timer.scheduledTimer(withTimeInterval: TimeInterval(1.0/60), repeats: true, block: { _ in
            if let event = self.dragEvent {
                self.mouseDragged(with: event)
            }
        })
        dragEvent = theEvent
        self.editorView.mouseDownHelper(event: theEvent)
    }
    
    func handleMouseDragged(with theEvent: NSEvent) {
        editorView.autoscroll(with: theEvent)
        dragEvent = theEvent
        self.editorView.mouseDownHelper(event: theEvent, drag: true)
    }
    
    func handleMouseUp(with theEvent: NSEvent) {
        dragTimer?.invalidate()
        dragTimer = nil
        dragEvent = nil
    }
    
    func increaseFontSize() {
        if preferences.editorFont.pointSize < 72 {
            preferences.editorFont = NSFont(name: preferences.editorFont.fontName, size: preferences.editorFont.pointSize + 1)!
            reload()
        }
    }
    
    func decreaseFontSize() {
        if preferences.editorFont.pointSize > 10 {
            preferences.editorFont = NSFont(name: preferences.editorFont.fontName, size: preferences.editorFont.pointSize - 1)!
            reload()
        }
    }
}
