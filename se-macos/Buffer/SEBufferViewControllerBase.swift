//
//  SEBufferViewControllerBase.swift
//  se-macos
//
//  Created by Chad Russell on 8/28/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

enum vim {
    // motions
    case left
    case right
    case up
    case down
    case word
    case bigWord
    case previousWord
    case previousBigWord
    case paragraph
    case previousParagraph
    case endOfWord
    case endOfLine
    case startOfLine
    case firstNonSpaceCharacterOfLine
    case untilForward
    case findForward
    case untilBackward
    case findBackward
    case inner
    case around
    
    // operations
    case delete
    case yank
    case change
    
    // replace
    case replace
    
    // repeat
    case repeatCount(value: Int)
    
    // raw characters (e.g. for 'replace')
    case rawChars(chars: String)
}

extension vim {
    var isOperation: Bool {
        switch self {
        case .delete:
            return true
        case .yank:
            return true
        case .change:
            return true
        case .replace:
            return true
        default:
            return false
        }
    }
}

extension vim: Equatable {
    static func ==(lhs: vim, rhs: vim) -> Bool {
        switch (lhs, rhs) {
        case (.left, .left): return true
        case (.right, .right): return true
        case (.up, .up): return true
        case (.down, .down): return true
        case (.word, .word): return true
        case (.bigWord, .bigWord): return true
        case (.previousWord, .previousWord): return true
        case (.previousBigWord, .previousBigWord): return true
        case (.paragraph, .paragraph): return true
        case (.previousParagraph, .previousParagraph): return true
        case (.endOfWord, .endOfWord): return true
        case (.endOfLine, .endOfLine): return true
        case (.startOfLine, .startOfLine): return true
        case (.firstNonSpaceCharacterOfLine, .firstNonSpaceCharacterOfLine): return true
        case (.delete, .delete): return true
        case (.yank, .yank): return true
        case (.change, .change): return true
        case (.replace, .replace): return true
        case (.repeatCount(_), .repeatCount(_)): return true
        case (.rawChars(_), .rawChars(_)): return true
        case (.untilForward, .untilForward): return true
        case (.findForward, .findForward): return true
        case (.untilBackward, .untilBackward): return true
        case (.findBackward, .findBackward): return true
        case (.inner, .inner): return true
        case (.around, .around): return true
        default: return false
        }
    }
}

class SEBufferViewControllerBase: NSViewController, SEBufferDelegate {
    @IBOutlet var editorView: SEEditorView!
    
    var preferences = SEEditorPreferences()
    var mode = SEMode.insert
    var buf: editor_buffer_t? = editor_buffer_create(80)
    let pasteboard = NSPasteboard.general
    
    var vimStack = [vim]()
    var lastVimStack = [vim]() // for '.' command
    
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
        let longestLine: Int64
        if preferences.virtualNewlines {
            longestLine = preferences.virtualNewlineLength
        } else {
            longestLine = editor_buffer_get_longest_line_length(buf!)
        }
        
        self.lineWidthConstraint?.constant = CGFloat(longestLine) * preferences.charWidth + 30
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
//        Swift.print(event.keyCode)
        
        switch mode {
        case .insert: handleKeyDownForInsertMode(event)
        case .normal: handleKeyDownForNormalMode(event)
        case .visual: handleKeyDownForNormalMode(event)
        }
        
        reload()
    }
    
    func handleKeyDownForInsertMode(_ event: NSEvent) {
        if event.keyCode == 48 {
            // tab
            editor_buffer_insert(buf!, preferences.tabs)
        } else if event.keyCode == 123 {
            // left
            editor_buffer_set_cursor_is_selection(buf!, event.modifierFlags.contains(.shift) ? 1 : 0)
            
            if event.modifierFlags.contains(.command) {
                if preferences.virtualNewlines {
                    editor_buffer_set_cursor_point_to_start_of_line_virtual(buf!, preferences.virtualNewlineLength)
                } else {
                    editor_buffer_set_cursor_point_to_start_of_line(buf!)
                }
            } else if event.modifierFlags.contains(.option) {
                editor_buffer_set_cursor_point_to_start_of_previous_word(buf!, preferences.wordSeparators)
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
                editor_buffer_set_cursor_point_to_start_of_next_word(buf!, preferences.wordSeparators)
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
                editor_buffer_copy_last_undo(buf!)
                
                editor_buffer_set_saves_to_undo(buf!, 0)
                editor_buffer_set_cursor_is_selection(buf!, 1)
                
                if preferences.virtualNewlines {
                    editor_buffer_set_cursor_point_to_start_of_line_virtual(buf!, preferences.virtualNewlineLength)
                } else {
                    editor_buffer_set_cursor_point_to_start_of_line(buf!)
                }
                
                editor_buffer_delete(buf!)
                editor_buffer_set_cursor_is_selection(buf!, 0)
                editor_buffer_set_saves_to_undo(buf!, 1)
            } else if event.modifierFlags.contains(.option) && editor_buffer_cursor_is_selection(buf!, 0) == 0 {
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_point_to_start_of_previous_word(buf!, preferences.wordSeparators)
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
            editor_buffer_set_cursor_is_selection(buf!, 0)
        } else if event.keyCode == 53 {
            // esc
            mode = .normal
            editor_buffer_set_cursor_is_selection(buf!, 0)
        } else if let chars = event.characters {
//            Swift.print(event.keyCode)
            
            editor_buffer_insert(buf!, chars)
            editor_buffer_set_cursor_is_selection(buf!, 0)
        }
        
        drawLastLine()
        sort_and_merge_cursors(buf!)
    }
    
    func handleKeyDownForNormalMode(_ event: NSEvent) {
        if !vimStack.isEmpty && (vimStack.last! == .replace || vimStack.last! == .untilForward || vimStack.last! == .findForward || vimStack.last! == .untilBackward || vimStack.last! == .findBackward), let chars = event.characters {
            vimStack.append(.rawChars(chars: chars))
        } else if !vimStack.isEmpty && (vimStack.last! == .inner || vimStack.last! == .around), let chars = event.characters, chars == "(" || chars == ")" || chars == "<" || chars == ">" || chars == "[" || chars == "]" || chars == "{" || chars == "}" || chars == "\"" || chars == "'" {
            vimStack.append(.rawChars(chars: chars))
        } else if event.keyCode == 53 {
            // esc
            mode = .normal
            editor_buffer_set_cursor_is_selection(buf!, 0)
        } else if event.keyCode == 33 && event.modifierFlags.contains(.control) {
            // ctrl + [
            mode = .normal
            editor_buffer_set_cursor_is_selection(buf!, 0)
        } else if event.keyCode == 33 {
            // {
            if event.modifierFlags.contains(.command) {
                editor_buffer_set_cursor_pos(buf!, 0)
            } else {
                vimStack.append(.previousParagraph)
            }
        } else if event.keyCode == 30 {
            // }
            if event.modifierFlags.contains(.command) {
                let charCount = editor_buffer_get_char_count(buf!)
                editor_buffer_set_cursor_pos(buf!, charCount)
            } else {
                vimStack.append(.paragraph)
            }
        } else if event.keyCode == 34 {
            // i
            let (visual, _) = mode.isVisual()
            if (!vimStack.isEmpty && vimStack.last!.isOperation) || visual {
                vimStack.append(.inner)
            } else {
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
            }
        } else if event.keyCode == 0 {
            // a
            let (visual, _) = mode.isVisual()
            if (!vimStack.isEmpty && vimStack.last!.isOperation) || visual {
                vimStack.append(.around)
            } else {
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
            }
        } else if event.keyCode == 4 {
            // h
            vimStack.append(.left)
        } else if event.keyCode == 38 {
            // j
            vimStack.append(.down)
        } else if event.keyCode == 40 {
            // k
            vimStack.append(.up)
        } else if event.keyCode == 37 {
            // l
            vimStack.append(.right)
        } else if event.keyCode == 9 {
            // v
            if event.modifierFlags.contains(.command) {
                editor_buffer_copy_last_undo(buf!)
                editor_buffer_set_saves_to_undo(buf!, 0)
                
                if event.modifierFlags.contains(.shift) {
                    if preferences.virtualNewlines {
                        editor_buffer_set_cursor_point_to_start_of_line_virtual(buf!, preferences.virtualNewlineLength)
                    } else {
                        editor_buffer_set_cursor_point_to_start_of_line(buf!)
                    }
                    
                    editor_buffer_set_cursor_pos_relative(buf!, -1)
                    editor_buffer_insert(buf!, "\n")
                    
                    var clipboardItems: [String] = []
                    for element in pasteboard.pasteboardItems! {
                        if let str = element.string(forType: NSPasteboard.PasteboardType(rawValue: "public.utf8-plain-text")) {
                            clipboardItems.append(str)
                        }
                    }
                    if clipboardItems.count > 0 {
                        let item = clipboardItems[0].trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
                        editor_buffer_insert(buf!, item)
                    }
                    
                    editor_buffer_set_cursor_is_selection(buf!, 0)
                } else {
                    if preferences.virtualNewlines {
                        editor_buffer_set_cursor_point_to_end_of_line_virtual(buf!, preferences.virtualNewlineLength)
                    } else {
                        editor_buffer_set_cursor_point_to_end_of_line(buf!)
                    }
                    
                    editor_buffer_insert(buf!, "\n")
                    
                    var clipboardItems: [String] = []
                    for element in pasteboard.pasteboardItems! {
                        if let str = element.string(forType: NSPasteboard.PasteboardType(rawValue: "public.utf8-plain-text")) {
                            clipboardItems.append(str)
                        }
                    }
                    if clipboardItems.count > 0 {
                        let item = clipboardItems[0].trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
                        editor_buffer_insert(buf!, item)
                    }
                    
                    editor_buffer_set_cursor_is_selection(buf!, 0)
                }
                
                editor_buffer_set_saves_to_undo(buf!, 1)
            } else {
                mode = .visual(line: event.modifierFlags.contains(.shift))
                
                editor_buffer_copy_last_undo(buf!)
                editor_buffer_set_cursor_is_selection(buf!, 1)
            }
        } else if event.keyCode == 2 {
            // d
            vimStack.append(.delete)
            if event.modifierFlags.contains(.shift) {
                vimStack.append(.endOfLine)
            }
        } else if event.keyCode == 13 {
            // w
            if event.modifierFlags.contains(.shift) {
                vimStack.append(.bigWord)
            } else {
                vimStack.append(.word)
            }
        } else if event.keyCode == 14 {
            // e
            vimStack.append(.endOfWord)
        } else if event.keyCode == 11 {
            // b
            if event.modifierFlags.contains(.shift) {
                vimStack.append(.previousBigWord)
            } else {
                vimStack.append(.previousWord)
            }
        } else if event.keyCode == 17 {
            // t
            if event.modifierFlags.contains(.shift) {
                vimStack.append(.untilBackward)
            } else {
                vimStack.append(.untilForward)
            }
        }
        else if event.keyCode == 3 {
            // f
            if event.modifierFlags.contains(.shift) {
                vimStack.append(.findBackward)
            } else {
                vimStack.append(.findForward)
            }
        } else if event.keyCode == 21 && event.modifierFlags.contains(.shift) {
            // $ (end-of-line)
            vimStack.append(.endOfLine)
        } else if event.keyCode == 22 && event.modifierFlags.contains(.shift) {
            // ^ (start-of-line)
            vimStack.append(.firstNonSpaceCharacterOfLine)
        } else if event.keyCode == 16 {
            // y
            vimStack.append(.yank)
        } else if event.keyCode == 31 {
            // o
            if event.modifierFlags.contains(.shift) {
                var firstRows: [Int64] = []
                
                for i in 0..<editor_buffer_get_cursor_count(buf!) {
                    if preferences.virtualNewlines {
                        let cursorRow = editor_buffer_get_cursor_row_virtual(buf!, i, preferences.virtualNewlineLength)
                        if cursorRow == 0 {
                            editor_buffer_set_cursor_point_for_cursor_index(buf!, i, 0, 0)
                            firstRows.append(i)
                        } else {
                            // set to the end of the previous row
                            let lineLength = editor_buffer_get_line_length_virtual(buf!, cursorRow - 1, preferences.virtualNewlineLength)
                            editor_buffer_set_cursor_point_virtual_for_cursor_index(buf!, i, cursorRow - 1, lineLength, preferences.virtualNewlineLength)
                        }
                    } else {
                        let cursorRow = editor_buffer_get_cursor_row(buf!, i)
                        if cursorRow == 0 {
                            editor_buffer_set_cursor_point_for_cursor_index(buf!, i, 0, 0)
                            firstRows.append(i)
                        } else {
                            // set to the end of the previous row
                            let lineLength = editor_buffer_get_line_length(buf!, cursorRow - 1)
                            editor_buffer_set_cursor_point_for_cursor_index(buf!, i, cursorRow - 1, lineLength)
                        }
                    }
                }
                
                editor_buffer_insert(buf!, "\n")
                for rowIdx in firstRows {
                    editor_buffer_set_cursor_point_for_cursor_index(buf!, rowIdx, 0, 0)
                }
            } else {
                if preferences.virtualNewlines {
                    editor_buffer_set_cursor_point_to_end_of_line_virtual(buf!, preferences.virtualNewlineLength)
                    editor_buffer_insert(buf!, "\n")
                } else {
                    editor_buffer_set_cursor_point_to_end_of_line(buf!)
                    editor_buffer_insert(buf!, "\n")
                }
            }
            
            mode = .insert
        } else if event.keyCode == 35 {
            // p
            if !vimStack.isEmpty && (vimStack.last! == .inner || vimStack.last! == .around) {
                vimStack.append(.rawChars(chars: "p"))
            } else {
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
            }
        } else if event.keyCode == 8 {
            // c
            vimStack.append(.change)
            if event.modifierFlags.contains(.shift) {
                vimStack.append(.endOfLine)
            }
        } else if event.keyCode == 7 {
            // x
            vimStack.append(.delete)
            vimStack.append(.right)
        } else if event.keyCode == 1 {
            // s
            if event.modifierFlags.contains(.shift) {
                vimStack.append(.firstNonSpaceCharacterOfLine)
                interpretVim() // need to interpret here otherwise it stops after this, lol
                
                vimStack.append(.change)
                vimStack.append(.endOfLine)
            } else {
                vimStack.append(.change)
                vimStack.append(.right)
            }
        } else if event.keyCode == 32 {
            // u
            if event.modifierFlags.contains(.shift) {
                let undo_idx = editor_buffer_get_global_undo_index(buf!)
                editor_buffer_global_undo(buf!, undo_idx - 1)
            } else {
                let undo_idx = editor_buffer_get_undo_index(buf!)
                editor_buffer_undo(buf!, undo_idx - 1)
            }
            editor_buffer_set_cursor_is_selection(buf!, 0)
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
            } else {
                vimStack.append(.replace)
            }
        } else if event.keyCode == 47 {
            // '.' / '>'
            if event.modifierFlags.contains(.shift) {
                editor_buffer_copy_last_undo(buf!)
                editor_buffer_set_saves_to_undo(buf!, 0)
                
                for cursorIdx in 0..<editor_buffer_get_cursor_count(buf!) {
                    let firstRow, lastRow: Int64
                    
                    if editor_buffer_cursor_is_selection(buf!, cursorIdx) == 1 {
                        let nonSelectionRow, selectionRow: Int64
                        
                        if preferences.virtualNewlines {
                            nonSelectionRow = editor_buffer_get_cursor_row_virtual(buf!, cursorIdx, preferences.virtualNewlineLength)
                            selectionRow = editor_buffer_get_cursor_selection_start_row_virtual(buf!, cursorIdx, preferences.virtualNewlineLength)
                        } else {
                            nonSelectionRow = editor_buffer_get_cursor_row(buf!, cursorIdx)
                            selectionRow = editor_buffer_get_cursor_selection_start_row(buf!, cursorIdx)
                        }
                        
                        firstRow = min(nonSelectionRow, selectionRow)
                        lastRow = max(nonSelectionRow, selectionRow)
                        
                        var canIndent = true
                        for row in firstRow...lastRow {
                            let rowLength = editor_buffer_get_line_length_virtual(buf!, row, preferences.virtualNewlineLength)
                            if Int(rowLength) + preferences.tabs.count >= preferences.virtualNewlineLength {
                                canIndent = false
                            }
                        }
                        
                        if !canIndent { continue }
                    } else {
                        if preferences.virtualNewlines {
                            firstRow = editor_buffer_get_cursor_row_virtual(buf!, cursorIdx, preferences.virtualNewlineLength)
                            
                            let rowLength = editor_buffer_get_line_length_virtual(buf!, firstRow, preferences.virtualNewlineLength)
                            if Int(rowLength) + preferences.tabs.count >= preferences.virtualNewlineLength {
                                continue
                            }
                        } else {
                            firstRow = editor_buffer_get_cursor_row(buf!, cursorIdx)
                        }
                        lastRow = firstRow
                    }
                    
                    for row in firstRow...lastRow {
                        editor_buffer_insert_at_point(buf!, preferences.tabs, row, 0, preferences.virtualNewlines ? 1 : 0, preferences.virtualNewlineLength)
                    }
                }
                
                editor_buffer_set_saves_to_undo(buf!, 1)
            } else {
                vimStack.append(contentsOf: lastVimStack)
            }
        } else if !event.modifierFlags.contains(.shift) && event.keyCode == 29 {
            // 0
            switch vimStack.last {
            case .repeatCount(let lastValue)?:
                vimStack[vimStack.count - 1] = .repeatCount(value: lastValue * 10)
            default:
                vimStack.append(.startOfLine)
            }
        } else if !event.modifierFlags.contains(.shift) && event.keyCode == 18 {
            // 1
            switch vimStack.last {
            case .repeatCount(let lastValue)?:
                vimStack[vimStack.count - 1] = .repeatCount(value: lastValue * 10 + 1)
            default:
                vimStack.append(.repeatCount(value: 1))
            }
        } else if !event.modifierFlags.contains(.shift) && event.keyCode == 19 {
            // 2
            switch vimStack.last {
            case .repeatCount(let lastValue)?:
                vimStack[vimStack.count - 1] = .repeatCount(value: lastValue * 10 + 2)
            default:
                vimStack.append(.repeatCount(value: 2))
            }
        } else if !event.modifierFlags.contains(.shift) && event.keyCode == 20 {
            // 3
            switch vimStack.last {
            case .repeatCount(let lastValue)?:
                vimStack[vimStack.count - 1] = .repeatCount(value: lastValue * 10 + 3)
            default:
                vimStack.append(.repeatCount(value: 3))
            }
        } else if !event.modifierFlags.contains(.shift) && event.keyCode == 21 {
            // 4
            switch vimStack.last {
            case .repeatCount(let lastValue)?:
                vimStack[vimStack.count - 1] = .repeatCount(value: lastValue * 10 + 4)
            default:
                vimStack.append(.repeatCount(value: 4))
            }
        } else if !event.modifierFlags.contains(.shift) && event.keyCode == 23 {
            // 5
            switch vimStack.last {
            case .repeatCount(let lastValue)?:
                vimStack[vimStack.count - 1] = .repeatCount(value: lastValue * 10 + 4)
            default:
                vimStack.append(.repeatCount(value: 4))
            }
        } else if event.modifierFlags.contains(.shift) && event.keyCode == 23 {
            // 5
            for i in (0 ..< editor_buffer_get_cursor_count(buf!)).reversed() {
                var startPos = editor_buffer_get_cursor_pos(buf!, i)
                var matchCount = 0
                
                let charAtCursor = charAt(startPos)
                let left, right: String
                let backward: Bool
                switch charAtCursor {
                case "(", ")":
                    left = "("
                    right = ")"
                    backward = charAtCursor == ")"
                case "[", "]":
                    left = "["
                    right = "]"
                    backward = charAtCursor == "]"
                case "{", "}":
                    left = "{"
                    right = "}"
                    backward = charAtCursor == "}"
                case "<", ">":
                    left = "<"
                    right = ">"
                    backward = charAtCursor == ">"
                default:
                    continue
                }
                
                let (visual, _) = mode.isVisual()
                
                if backward && visual {
                    editor_buffer_set_cursor_is_selection_for_cursor_index(buf!, i, 0)
                    editor_buffer_set_cursor_pos_relative_for_cursor_index(buf!, i, 1)
                    editor_buffer_set_cursor_is_selection_for_cursor_index(buf!, i, 1)
                }
                
                let charCount = editor_buffer_get_char_count(buf!)
                let targetChar = backward ? left : right
                let nonTargetChar = backward ? right : left
                while startPos >= 0 && startPos < charCount {
                    let char = charAt(startPos)
                    if char == targetChar {
                        matchCount -= 1
                    } else if char == nonTargetChar {
                        matchCount += 1
                    }
                    if matchCount == 0 {
                        if !visual {
                            editor_buffer_set_cursor_is_selection_for_cursor_index(buf!, i, 0)
                        }
                        editor_buffer_set_cursor_pos_for_cursor_index(buf!, i, startPos)
                        break
                    }
                    
                    startPos += backward ? -1 : 1
                }
                
                if !backward && visual {
                    editor_buffer_set_cursor_pos_relative_for_cursor_index(buf!, i, 1)
                }
            }
        } else if !event.modifierFlags.contains(.shift) && event.keyCode == 22 {
            // 6
            switch vimStack.last {
            case .repeatCount(let lastValue)?:
                vimStack[vimStack.count - 1] = .repeatCount(value: lastValue * 10 + 5)
            default:
                vimStack.append(.repeatCount(value: 5))
            }
        } else if !event.modifierFlags.contains(.shift) && event.keyCode == 26 {
            // 7
            switch vimStack.last {
            case .repeatCount(let lastValue)?:
                vimStack[vimStack.count - 1] = .repeatCount(value: lastValue * 10 + 7)
            default:
                vimStack.append(.repeatCount(value: 7))
            }
        } else if !event.modifierFlags.contains(.shift) && event.keyCode == 28 {
            // 8
            switch vimStack.last {
            case .repeatCount(let lastValue)?:
                vimStack[vimStack.count - 1] = .repeatCount(value: lastValue * 10 + 8)
            default:
                vimStack.append(.repeatCount(value: 8))
            }
        } else if !event.modifierFlags.contains(.shift) && event.keyCode == 25 {
            // 9
            switch vimStack.last {
            case .repeatCount(let lastValue)?:
                vimStack[vimStack.count - 1] = .repeatCount(value: lastValue * 10 + 9)
            default:
                vimStack.append(.repeatCount(value: 9))
            }
        } else if event.keyCode == 43 && event.modifierFlags.contains(.shift) {
            // '<'
            if event.modifierFlags.contains(.shift) {
                editor_buffer_copy_last_undo(buf!)
                editor_buffer_set_saves_to_undo(buf!, 0)
                
                for cursorIdx in 0..<editor_buffer_get_cursor_count(buf!) {
                    let firstRow, lastRow: Int64
                    
                    if editor_buffer_cursor_is_selection(buf!, cursorIdx) == 1 {
                        let nonSelectionRow, selectionRow: Int64
                        
                        if preferences.virtualNewlines {
                            nonSelectionRow = editor_buffer_get_cursor_row_virtual(buf!, cursorIdx, preferences.virtualNewlineLength)
                            selectionRow = editor_buffer_get_cursor_selection_start_row_virtual(buf!, cursorIdx, preferences.virtualNewlineLength)
                        } else {
                            nonSelectionRow = editor_buffer_get_cursor_row(buf!, cursorIdx)
                            selectionRow = editor_buffer_get_cursor_selection_start_row(buf!, cursorIdx)
                        }
                        
                        firstRow = min(nonSelectionRow, selectionRow)
                        lastRow = max(nonSelectionRow, selectionRow)
                    } else {
                        if preferences.virtualNewlines {
                            firstRow = editor_buffer_get_cursor_row_virtual(buf!, cursorIdx, preferences.virtualNewlineLength)
                            
                            let rowLength = editor_buffer_get_line_length_virtual(buf!, firstRow, preferences.virtualNewlineLength)
                            if Int(rowLength) + preferences.tabs.count >= preferences.virtualNewlineLength {
                                continue
                            }
                        } else {
                            firstRow = editor_buffer_get_cursor_row(buf!, cursorIdx)
                        }
                        lastRow = firstRow
                    }
                    
                    for row in firstRow...lastRow {
                        let stringBuf: OpaquePointer!
                        if preferences.virtualNewlines {
                            stringBuf = editor_buffer_get_text_between_points_virtual(buf!, row, 0, row, Int64(preferences.tabs.count), preferences.virtualNewlineLength)
                        } else {
                            stringBuf = editor_buffer_get_text_between_points(buf!, row, 0, row, Int64(preferences.tabs.count))
                        }
                        defer {
                            editor_buffer_free_buf(stringBuf)
                        }
                        guard let bufBytes = editor_buffer_get_buf_bytes(stringBuf) else {
                            return
                        }
                        let swiftString = String(cString: bufBytes)
                        
                        if swiftString.starts(with: preferences.tabs) {
                            editor_buffer_delete_at_point(buf!, Int64(preferences.tabs.count), row, Int64(preferences.tabs.count), preferences.virtualNewlines ? 1 : 0, preferences.virtualNewlineLength)
                        }
                    }
                }
                
                editor_buffer_set_saves_to_undo(buf!, 1)
            }
        }
        
        interpretVim()
        sort_and_merge_cursors(buf!)
        drawLastLine()
    }
    
    func interpretVimAtIndex(_ index: Int) -> Bool {
        if vimStack.count <= index { return false }
        
        switch vimStack[index] {
        case .left:
            editor_buffer_set_cursor_pos_relative(buf!, -1)
        case .right:
            editor_buffer_set_cursor_pos_relative(buf!, 1)
        case .up:
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

            sort_and_merge_cursors(buf!)
        case .down:
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

            sort_and_merge_cursors(buf!)
        case .word:
            editor_buffer_set_cursor_point_to_start_of_next_word(buf!, preferences.wordSeparators)
        case .bigWord:
            editor_buffer_set_cursor_point_to_start_of_next_word(buf!, preferences.bigWordSeparators)
        case .previousWord:
            editor_buffer_set_cursor_point_to_start_of_previous_word(buf!, preferences.wordSeparators)
        case .previousBigWord:
            editor_buffer_set_cursor_point_to_start_of_previous_word(buf!, preferences.bigWordSeparators)
        case .paragraph:
            editor_buffer_set_cursor_point_to_end_of_current_paragraph(buf!,
                                                                       preferences.virtualNewlines ? 1 : 0,
                                                                       preferences.virtualNewlineLength);
        case .previousParagraph:
            editor_buffer_set_cursor_point_to_start_of_current_paragraph(buf!,
                                                                         preferences.virtualNewlines ? 1 : 0,
                                                                         preferences.virtualNewlineLength);
        case .endOfWord:
            editor_buffer_set_cursor_point_to_end_of_current_word(buf!, preferences.wordSeparators)
        case .endOfLine:
            if preferences.virtualNewlines {
                editor_buffer_set_cursor_point_to_end_of_line_virtual(buf!, preferences.virtualNewlineLength)
            } else {
                editor_buffer_set_cursor_point_to_end_of_line(buf!)
            }
        case .startOfLine:
            editor_buffer_set_saves_to_undo(buf!, 0)
            if preferences.virtualNewlines {
                editor_buffer_set_cursor_point_to_start_of_line_virtual(buf!, preferences.virtualNewlineLength)
            } else {
                editor_buffer_set_cursor_point_to_start_of_line(buf!)
            }
        case .firstNonSpaceCharacterOfLine:
            editor_buffer_set_saves_to_undo(buf!, 0)
            if preferences.virtualNewlines {
                editor_buffer_set_cursor_point_to_start_of_line_virtual(buf!, preferences.virtualNewlineLength)
            } else {
                editor_buffer_set_cursor_point_to_start_of_line(buf!)
            }
            for cursorIdx in 0..<editor_buffer_get_cursor_count(buf!) {
                var space = true
                while space {
                    let cursorPos = editor_buffer_get_cursor_pos(buf!, cursorIdx)
                    let char = charAt(cursorPos)
                    if char.hasPrefix(" ") || char.hasPrefix("\t") {
                        editor_buffer_set_cursor_pos_for_cursor_index(buf!, cursorIdx, cursorPos + 1)
                    } else {
                        space = false
                    }
                }
            }
        case .delete:
            let (isVisual, isLine) = mode.isVisual()
            if isVisual {
                if isLine {
                    extendSelectionToLines()
                }
                
                copySelection()
                editor_buffer_delete(buf!)
                editor_buffer_set_cursor_is_selection(buf!, 0)
                mode = .normal
            } else if index > 0 && vimStack[index - 1] == .delete {
                editor_buffer_copy_last_undo(buf!)
                editor_buffer_set_cursor_is_selection(buf!, 1)
                extendSelectionToLines()
            } else {
                editor_buffer_set_cursor_is_selection(buf!, 1)

                if !interpretVimAtIndex(index + 1) { return false }
                
                switch vimStack[index + 1] {
                case .down:
                    extendSelectionToLines()
                case .up:
                    extendSelectionToLines()
                case .repeatCount(_):
                    switch vimStack[index + 2] {
                    case .down:
                        extendSelectionToLines()
                    case .up:
                        extendSelectionToLines()
                    default: break
                    }
                default: break
                }
                
                copySelection()
                editor_buffer_delete(buf!)

                editor_buffer_set_cursor_is_selection(buf!, 0)
            }
        case .yank:
            let (isVisual, isLine) = mode.isVisual()
            if isVisual {
                if isLine {
                    extendSelectionToLines()
                }
            } else if index > 0 && vimStack[index - 1] == .yank {
                editor_buffer_set_cursor_is_selection(buf!, 1)
                extendSelectionToLines()
            } else {
                editor_buffer_set_cursor_is_selection(buf!, 1)
                
                if !interpretVimAtIndex(index + 1) { return false }
            }
            
            copySelection()
            editor_buffer_set_cursor_is_selection(buf!, 0)
        case .change:
            let (isVisual, isLine) = mode.isVisual()
            if isVisual {
                if isLine {
                    extendSelectionToLines()
                }
                
                copySelection()
                editor_buffer_delete(buf!)
            } else {
                editor_buffer_set_cursor_is_selection(buf!, 1)
                
                if !interpretVimAtIndex(index + 1) { return false }
                copySelection()
                editor_buffer_delete(buf!)
                
                editor_buffer_set_cursor_is_selection(buf!, 0)
            }
            
            mode = .insert
        case .untilForward:
            if vimStack.count <= index + 1 { return false }
            switch vimStack[index + 1] {
            case .rawChars(let chars):
                for i in 0 ..< editor_buffer_get_cursor_count(buf!) {
                    let startSearchPos = editor_buffer_get_cursor_pos(buf!, i) + 1
                    let newPos = editor_buffer_search_forward(buf!, chars, startSearchPos)
                    if newPos > -1 {
                        editor_buffer_set_cursor_pos_for_cursor_index(buf!, i, newPos)
                    }
                }
            default:
                return false
            }
        case .untilBackward:
            if vimStack.count <= index + 1 { return false }
            switch vimStack[index + 1] {
            case .rawChars(let chars):
                for i in 0 ..< editor_buffer_get_cursor_count(buf!) {
                    let newPos = editor_buffer_search_backward(buf!, chars, editor_buffer_get_cursor_pos(buf!, i) + 1) + 1
                    if newPos > 0 {
                        editor_buffer_set_cursor_pos_for_cursor_index(buf!, i, newPos)
                    }
                }
            default:
                return false
            }
        case .findForward:
            if vimStack.count <= index + 1 { return false }
            switch vimStack[index + 1] {
            case .rawChars(let chars):
                for i in 0 ..< editor_buffer_get_cursor_count(buf!) {
                    let newPos = editor_buffer_search_forward(buf!, chars, editor_buffer_get_cursor_pos(buf!, i) + 1) + 1
                    if newPos > 0 {
                        editor_buffer_set_cursor_pos_for_cursor_index(buf!, i, newPos)
                    }
                }
            default:
                return false
            }
        case .findBackward:
            if vimStack.count <= index + 1 { return false }
            switch vimStack[index + 1] {
            case .rawChars(let chars):
                for i in 0 ..< editor_buffer_get_cursor_count(buf!) {
                    let newPos = editor_buffer_search_backward(buf!, chars, editor_buffer_get_cursor_pos(buf!, i) - 1)
                    if newPos > -1 {
                        editor_buffer_set_cursor_pos_for_cursor_index(buf!, i, newPos)
                    }
                }
            default:
                return false
            }
        case .inner:
            if vimStack.count <= index + 1 { return false }
            switch vimStack[index + 1] {
            case .word:
                editor_buffer_set_cursor_is_selection(buf!, 0)
                editor_buffer_set_cursor_point_to_start_of_previous_word(buf!, preferences.wordSeparators)
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_point_to_start_of_next_word(buf!, preferences.wordSeparators)
            case .bigWord:
                editor_buffer_set_cursor_is_selection(buf!, 0)
                editor_buffer_set_cursor_point_to_start_of_previous_word(buf!, preferences.bigWordSeparators)
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_point_to_start_of_next_word(buf!, preferences.bigWordSeparators)
            case .endOfWord:
                editor_buffer_set_cursor_is_selection(buf!, 0)
                editor_buffer_set_cursor_point_to_start_of_previous_word(buf!, preferences.wordSeparators)
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_point_to_end_of_current_word(buf!, preferences.wordSeparators)
            case .rawChars(chars: "p"):
                editor_buffer_set_cursor_is_selection(buf!, 0)
                editor_buffer_set_cursor_point_to_start_of_current_paragraph(buf!, preferences.virtualNewlines ? 1 : 0, preferences.virtualNewlineLength)
                editor_buffer_set_cursor_pos_relative(buf!, 1)
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_point_to_end_of_current_paragraph(buf!, preferences.virtualNewlines ? 1 : 0, preferences.virtualNewlineLength)
            case .rawChars(chars: "\""):
                highlightBetween("\"")
            case .rawChars(chars: "'"):
                highlightBetween("'")
            case .rawChars(chars: ")"):
                highlightBetweenMatching(left: "(", right: ")")
            case .rawChars(chars: "("):
                highlightBetweenMatching(left: "(", right: ")")
            case .rawChars(chars: "<"):
                highlightBetweenMatching(left: "<", right: ">")
            case .rawChars(chars: ">"):
                highlightBetweenMatching(left: "<", right: ">")
            case .rawChars(chars: "["):
                highlightBetweenMatching(left: "[", right: "]")
            case .rawChars(chars: "]"):
                highlightBetweenMatching(left: "[", right: "]")
            case .rawChars(chars: "{"):
                highlightBetweenMatching(left: "{", right: "}")
            case .rawChars(chars: "}"):
                highlightBetweenMatching(left: "{", right: "}")
            default:
                Swift.print("unrecognized delete inner for vimStack: \(vimStack)")
            }
        case .around:
            if vimStack.count <= index + 1 { return false }
            switch vimStack[index + 1] {
            case .word:
                editor_buffer_set_cursor_is_selection(buf!, 0)
                editor_buffer_set_cursor_point_to_start_of_previous_word(buf!, preferences.wordSeparators)
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_point_to_start_of_next_word(buf!, preferences.wordSeparators)
            case .bigWord:
                editor_buffer_set_cursor_is_selection(buf!, 0)
                editor_buffer_set_cursor_point_to_start_of_previous_word(buf!, preferences.bigWordSeparators)
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_point_to_start_of_next_word(buf!, preferences.bigWordSeparators)
            case .endOfWord:
                editor_buffer_set_cursor_is_selection(buf!, 0)
                editor_buffer_set_cursor_point_to_start_of_previous_word(buf!, preferences.wordSeparators)
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_point_to_end_of_current_word(buf!, preferences.wordSeparators)
            case .rawChars(chars: "p"):
                editor_buffer_set_cursor_is_selection(buf!, 0)
                editor_buffer_set_cursor_point_to_start_of_current_paragraph(buf!, preferences.virtualNewlines ? 1 : 0, preferences.virtualNewlineLength)
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_point_to_end_of_current_paragraph(buf!, preferences.virtualNewlines ? 1 : 0, preferences.virtualNewlineLength)
            case .rawChars(chars: "\""):
                highlightBetween("\"", includeEnds: true)
            case .rawChars(chars: "'"):
                highlightBetween("'", includeEnds: true)
            case .rawChars(chars: ")"):
                highlightBetweenMatching(left: "(", right: ")", includeEnds: true)
            case .rawChars(chars: "("):
                highlightBetweenMatching(left: "(", right: ")", includeEnds: true)
            case .rawChars(chars: "<"):
                highlightBetweenMatching(left: "<", right: ">", includeEnds: true)
            case .rawChars(chars: ">"):
                highlightBetweenMatching(left: "<", right: ">", includeEnds: true)
            case .rawChars(chars: "["):
                highlightBetweenMatching(left: "[", right: "]", includeEnds: true)
            case .rawChars(chars: "]"):
                highlightBetweenMatching(left: "[", right: "]", includeEnds: true)
            case .rawChars(chars: "{"):
                highlightBetweenMatching(left: "{", right: "}", includeEnds: true)
            case .rawChars(chars: "}"):
                highlightBetweenMatching(left: "{", right: "}", includeEnds: true)
            default:
                Swift.print("unrecognized delete around for vimStack: \(vimStack)")
            }
        case .replace:
            if vimStack.count <= index + 1 { return false }
            
            let (isVisual, _) = mode.isVisual()
            if !isVisual {
                editor_buffer_set_cursor_is_selection(buf!, 1)
                editor_buffer_set_cursor_pos_relative(buf!, 1)
            }
            
            copySelection()
            editor_buffer_delete(buf!)
            if !interpretVimAtIndex(index + 1) { return false }
        case .repeatCount(let value):
            for _ in 0 ..< value {
                if !interpretVimAtIndex(index + 1) { return false }
            }
        case .rawChars(let chars):
            editor_buffer_insert(buf!, chars)
        }
        
        return true
    }
    
    func highlightBetween(_ chars: String, includeEnds: Bool = false) {
        for i in (0 ..< editor_buffer_get_cursor_count(buf!)).reversed() {
            editor_buffer_set_cursor_is_selection_for_cursor_index(buf!, i, 0)
            
            let oldPos = editor_buffer_get_cursor_pos(buf!, i)
            let startHighlightPos = editor_buffer_search_backward(buf!, chars, editor_buffer_get_cursor_pos(buf!, i) - 1)
            if startHighlightPos > -1 {
                editor_buffer_set_cursor_pos_for_cursor_index(buf!, i, includeEnds ? startHighlightPos : startHighlightPos + 1)
                editor_buffer_set_cursor_is_selection_for_cursor_index(buf!, i, 1)

                let newPos = editor_buffer_search_forward(buf!, chars, editor_buffer_get_cursor_pos(buf!, i) + 1)
                if newPos > 0 {
                    editor_buffer_set_cursor_pos_for_cursor_index(buf!, i, includeEnds ? newPos + 1 : newPos)
                } else {
                    editor_buffer_set_cursor_pos_for_cursor_index(buf!, i, oldPos)
                }
            } else {
                editor_buffer_set_cursor_pos_for_cursor_index(buf!, i, oldPos)
            }
        }
    }
    
    func highlightBetweenMatching(left: String, right: String, includeEnds: Bool = false) {
        for i in (0 ..< editor_buffer_get_cursor_count(buf!)).reversed() {
            editor_buffer_set_cursor_is_selection_for_cursor_index(buf!, i, 0)
            
            var startPos = editor_buffer_get_cursor_pos(buf!, i)
            var matchCount = 0
            
            while startPos >= 0 {
                let char = charAt(startPos)
                if char == left {
                    matchCount -= 1
                }
                if char == right {
                    matchCount += 1
                }
                if matchCount == -1 {
                    startPos += 1
                    editor_buffer_set_cursor_pos_for_cursor_index(buf!, i, startPos)
                    break
                }
                startPos -= 1
            }
            
            if matchCount == -1 {
                if includeEnds {
                    editor_buffer_set_cursor_pos_relative(buf!, -1)
                }
                
                editor_buffer_set_cursor_is_selection_for_cursor_index(buf!, i, 1)
                
                while startPos < editor_buffer_get_char_count(buf!) && matchCount != 0 {
                    let char = charAt(startPos)
                    if char == left {
                        matchCount -= 1
                    }
                    if char == right {
                        matchCount += 1
                    }
                    if matchCount == 0 {
                        editor_buffer_set_cursor_pos_for_cursor_index(buf!, i, startPos)
                    }
                    startPos += 1
                }
                
                if includeEnds {
                    editor_buffer_set_cursor_pos_relative(buf!, 1)
                }
            }
        }
    }
    
    func charAt(_ n: Int64) -> String {
        let stringBuf = editor_buffer_get_text_between_characters(buf!, n, n + 1)
        defer {
            editor_buffer_free_buf(stringBuf)
        }
        
        let bufBytes = editor_buffer_get_buf_bytes(stringBuf)
        if bufBytes != nil {
            return String(cString: bufBytes!)
        }
        return ""
    }
    
    func interpretVim() {
        if vimStack.isEmpty { return }
        
        // todo(chad): @Hack there should be a 'canInterpretVim' func or something that gives the same result as
        // 'interpretVimAtIndex' but without actually interpreting anything
        switch vimStack.first! {
        case .endOfLine:
            editor_buffer_copy_last_undo(buf!)
        case .startOfLine:
            editor_buffer_copy_last_undo(buf!)
        case .replace:
            if vimStack.count > 1 {
                editor_buffer_copy_last_undo(buf!)
            }
        case .change:
            if vimStack.count > 1 {
                editor_buffer_copy_last_undo(buf!)
            }
        case .delete:
            if vimStack.count > 1 {
                editor_buffer_copy_last_undo(buf!)
            }
        case .repeatCount(_):
            if vimStack.count > 2 {
                editor_buffer_copy_last_undo(buf!)
            }
        default:
            ()
        }
        editor_buffer_set_saves_to_undo(buf!, 0)
        
        defer { editor_buffer_set_saves_to_undo(buf!, 1) }
        
        if !interpretVimAtIndex(0) { return }
        
        if !vimStack.isEmpty && vimStack[0].isOperation {
            lastVimStack = vimStack
        }
        
        vimStack = []
        
        let (isVisual, _) = mode.isVisual()
        if !isVisual {
            editor_buffer_set_cursor_is_selection(buf!, 0)
        }
    }
    
    func extendSelectionToLines() {
        for i in 0..<editor_buffer_get_cursor_count(buf!) {
            if editor_buffer_cursor_is_selection(buf!, i) != 1 { continue }
            
            // set selection to start of line
            if preferences.virtualNewlines {
                let cursorRow = editor_buffer_get_cursor_row_virtual(buf!, i, preferences.virtualNewlineLength)
                
                let selectionRow = editor_buffer_get_cursor_selection_start_row_virtual(buf!, i, preferences.virtualNewlineLength)
                
                let bottomRow = max(cursorRow, selectionRow)
                let topRow = min(cursorRow, selectionRow)
                
                editor_buffer_set_cursor_is_selection_for_cursor_index(buf!, i, 0)
                
                // set cursor to end of line
                editor_buffer_set_cursor_point_virtual_for_cursor_index(buf!, i, bottomRow + 1, 0, preferences.virtualNewlineLength)
                
                editor_buffer_set_cursor_is_selection_for_cursor_index(buf!, i, 1)
                
                // set cursor to start of line
                editor_buffer_set_cursor_point_virtual_for_cursor_index(buf!, i, topRow, 0, preferences.virtualNewlineLength)
            } else {
                let cursorRow = editor_buffer_get_cursor_row(buf!, i)
                
                let selectionRow = editor_buffer_get_cursor_selection_start_row(buf!, i)
                
                let bottomRow = max(cursorRow, selectionRow)
                let topRow = min(cursorRow, selectionRow)
                
                editor_buffer_set_cursor_is_selection_for_cursor_index(buf!, i, 0)
                
                // find the last line
                let lastLine: Int64
                if preferences.virtualNewlines {
                    lastLine = editor_buffer_get_line_count_virtual(buf!, preferences.virtualNewlineLength) - 1
                } else {
                    lastLine = editor_buffer_get_line_count(buf!) - 1
                }
                
                // set cursor to start of line
                editor_buffer_set_cursor_point_for_cursor_index(buf!, i, topRow, 0)
                if bottomRow >= lastLine {
                    editor_buffer_set_cursor_pos_relative_for_cursor_index(buf!, i, -1)
                }
                
                editor_buffer_set_cursor_is_selection_for_cursor_index(buf!, i, 1)
                
                // set cursor to the end of the line
                if bottomRow >= lastLine {
                    editor_buffer_set_cursor_pos_relative_for_cursor_index(buf!, i, 1)
                    
                    if preferences.virtualNewlines {
                        editor_buffer_set_cursor_point_to_end_of_line_virtual_for_cursor_index(buf!, i, preferences.virtualNewlineLength)
                    } else {
                        editor_buffer_set_cursor_point_to_end_of_line_for_cursor_index(buf!, i)
                    }
                } else {
                    editor_buffer_set_cursor_point_for_cursor_index(buf!, i, bottomRow + 1, 0)
                }
            }
        }
    }
    
    func copySelection() {
        var swiftString = ""
        let cursorCount = editor_buffer_get_cursor_count(buf!)
        for i in 0 ..< cursorCount {
            if editor_buffer_cursor_is_selection(buf!, i) != 1 { continue }
            
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
            
            if let color = parseColor(json: json!, key: "footer_background_color") {
                preferences.footerBackgroundColor = color
            }
            
            if let color = parseColor(json: json!, key: "footer_text_color") {
                preferences.footerTextColor = color
            }
            
            if let color = parseColor(json: json!, key: "cursor_color") {
                preferences.cursorColor = color
            }
            
            if let color = parseColor(json: json!, key: "selection_color") {
                preferences.selectionColor = color
            }
            
            if let tabs = json!["tabs"] as? String {
                preferences.tabs = tabs
            }
            
            if let wordSeparators = json!["word_separators"] as? String {
                preferences.wordSeparators = wordSeparators
            }
            
            if let bigWordSeparators = json!["big_word_separators"] as? String {
                preferences.bigWordSeparators = bigWordSeparators
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
        
        self.editorView.mouseUp(with: theEvent)
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
