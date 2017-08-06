//
//  SETableCellView.swift
//  se-macos
//
//  Created by Chad Russell on 7/25/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SETableCellView : NSTableCellView {
    
    var row: Int?
    var controller: SETextTableViewController?
    var cursorView: NSView?
    
    func highlightCharAt(col: Int) {
        var textStorage = NSTextStorage(string: self.textField!.stringValue)
        if textStorage.length == 0 {
            textStorage = NSTextStorage(string: "C")
        }
        
        let textContainer = NSTextContainer(size: self.textField!.bounds.size)
        let layoutManager = NSLayoutManager()
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        textStorage.addAttribute(NSFontAttributeName, value: self.textField!.font!, range: NSRange(location: 0, length: textStorage.length))
        textContainer.lineFragmentPadding = 0
        
        layoutManager.ensureLayout(for: textContainer)
        
        cursorView?.removeFromSuperview()
        
        var boundingRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: col, length: 1), in: textContainer)
        if boundingRect.width == 0 {
            boundingRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: col - 1, length: 1), in: textContainer)
            boundingRect.origin.x += boundingRect.width
        }
        
        cursorView = NSView(frame: CGRect(x: self.frame.origin.x + boundingRect.origin.x,
            y: self.frame.origin.y + boundingRect.origin.y,
            width: boundingRect.width,
            height: boundingRect.height))
        cursorView!.wantsLayer = true
        cursorView!.layer?.backgroundColor = NSColor.green.cgColor
        cursorView!.layer?.opacity = 0.5
        self.addSubview(cursorView!)
    }
    
    func colForCharAt(point: NSPoint) -> Int {
        let textStorage = NSTextStorage(string: self.textField!.stringValue)
        let textContainer = NSTextContainer(size: self.textField!.bounds.size)
        let layoutManager = NSLayoutManager()
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        textStorage.addAttribute(NSFontAttributeName, value: self.textField!.font!, range: NSRange(location: 0, length: textStorage.length))
        textContainer.lineFragmentPadding = 0
        
        layoutManager.ensureLayout(for: textContainer)
        
        let glyph = layoutManager.glyphIndex(for: point, in: textContainer)
        return glyph
    }
    
    func reload() {
        if row == nil { return }
        if controller == nil { return }
        if controller!.buf == nil { return }
        
        let row64 = Int64(row!)
        
        let stringBuf: OpaquePointer?
        if controller!.virtualNewlines {
            stringBuf = editor_buffer_get_text_between_virtual_points(controller!.screen!, row64, 0, row64 + 1, 0, controller!.virtualNewlineLength)
        } else {
            stringBuf = editor_buffer_get_text_between_points(controller!.screen!, row64, 0, row64 + 1, 0)!
        }
        
        defer {
            editor_buffer_free_buf(stringBuf)
        }
        
        let bufBytes = editor_buffer_get_buf_bytes(stringBuf)
        let swiftString = String(cString: bufBytes!)
        self.textField?.stringValue = swiftString
        
        let cursorRow: Int64
        if controller!.virtualNewlines {
            cursorRow = editor_screen_get_cursor_row_virtual(editor_buffer_get_current_screen(controller!.buf!), controller!.virtualNewlineLength)
        } else {
            cursorRow = editor_screen_get_cursor_row(editor_buffer_get_current_screen(controller!.buf!))
        }
        
        if cursorRow == row64 {
            let col: Int64
            if controller!.virtualNewlines {
                col = editor_screen_get_cursor_col_virtual(editor_buffer_get_current_screen(controller!.buf!), controller!.virtualNewlineLength)
            } else {
                col = editor_screen_get_cursor_col(editor_buffer_get_current_screen(controller!.buf!))
            }
            
            highlightCharAt(col: Int(col))
        } else {
            cursorView?.removeFromSuperview()
        }
    }
    
}
