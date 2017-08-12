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
    
    @IBOutlet weak var row0: SETextLineView!
    @IBOutlet weak var row1: SETextLineView!
    @IBOutlet weak var row2: SETextLineView!
    @IBOutlet weak var row3: SETextLineView!
    
    var controller: SETextTableViewController?
//    var selectionView: NSView?
//    var cursorView: NSView?
    
//    func coordinatesForCharacter(col: Int) -> CGPoint {
//        let textStorage = NSTextStorage(string: self.textField!.stringValue)
//        
//        // todo(chad): @hack ??
////        let textContainer = NSTextContainer(size: self.textField!.bounds.size)
////        let textContainer = NSTextContainer(size: CGSize(width: controller!.widestColumn + 1000, height: self.frame.size.height))
//        let textContainer = NSTextContainer(size: CGSize(width: 1000000, height: self.frame.size.height))
//        
//        let layoutManager = NSLayoutManager()
//        
//        layoutManager.addTextContainer(textContainer)
//        textStorage.addLayoutManager(layoutManager)
//        
//        textStorage.addAttribute(NSFontAttributeName, value: self.textField!.font!, range: NSRange(location: 0, length: textStorage.length))
//        textContainer.lineFragmentPadding = 0
//        
//        layoutManager.ensureLayout(for: textContainer)
//        
//        var glyph = 0
//        for _ in 0..<col {
//            let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: glyph, length: 1), actualCharacterRange: nil)
//            glyph += glyphRange.length
//        }
//        
//        var boundingRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
//        if boundingRect.width == 0 {
//            boundingRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph - 1, length: 1), in: textContainer)
//            boundingRect.origin.x += boundingRect.width
//        }
//        
//        // todo(chad): + 2 seems like a hack??
//        let localCoordinates = CGPoint(x: self.textField!.frame.origin.x + boundingRect.origin.x + 2,
//                                       y: self.frame.height)
//        return localCoordinates
//    }
//    
//    func colForCharAt(point: NSPoint) -> Int {
//        let textStorage = NSTextStorage(string: self.textField!.stringValue)
//        let textContainer = NSTextContainer(size: self.textField!.bounds.size)
//        let layoutManager = NSLayoutManager()
//        
//        layoutManager.addTextContainer(textContainer)
//        textStorage.addLayoutManager(layoutManager)
//        
//        textStorage.addAttribute(NSFontAttributeName, value: self.textField!.font!, range: NSRange(location: 0, length: textStorage.length))
//        textContainer.lineFragmentPadding = 0
//        
//        layoutManager.ensureLayout(for: textContainer)
//        
//        let pointInTextField = NSPoint(x: point.x - self.textField!.frame.origin.x, y: point.y - self.textField!.frame.origin.y)
//        
//        let glyphIndex = layoutManager.glyphIndex(for: pointInTextField, in: textContainer)
//        
//        let boundingRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
//        
//        if pointInTextField.x > boundingRect.origin.x + boundingRect.width * 3 / 4 {
//            return glyphIndex + 1
//        }
//        
//        return glyphIndex
//    }
    
    func reload() {
        if row == nil { return }
        if controller == nil { return }
        if controller!.buf == nil { return }
        
//        self.lineNumberView.stringValue = "\(row!)"
        
        let row64 = Int64(row!)
        
        let stringBuf: OpaquePointer?
        if controller!.virtualNewlines {
            stringBuf = editor_buffer_get_text_between_points_virtual(controller!.buf!, row64, 0, row64 + 1, 0, controller!.virtualNewlineLength)
        } else {
            let rowLength = editor_buffer_get_line_length(controller!.buf!, row64)
            stringBuf = editor_buffer_get_text_between_points(controller!.buf!, row64, 0, row64, rowLength)!
        }
        
        defer {
            editor_buffer_free_buf(stringBuf)
        }
        
//        let bufBytes = editor_buffer_get_buf_bytes(stringBuf)
//        if bufBytes != nil {
//            let swiftString = String(cString: bufBytes!)
//            self.textField?.stringValue = swiftString
//        }
        
//        self.layoutSubtreeIfNeeded()

//        drawCursor()
//        drawSelection()
    }
    
//    func drawCursor() {
//        // draw cursor!
//        let virtualNewlines = controller!.virtualNewlines
//        let virtualNewlineLength = controller!.virtualNewlineLength
//        let buf = controller?.buf
//        
//        let cursorRow: Int
//        if virtualNewlines {
//            cursorRow = Int(editor_buffer_get_cursor_row_virtual(buf!, virtualNewlineLength))
//        } else {
//            cursorRow = Int(editor_buffer_get_cursor_row(buf!))
//        }
//
//        let cursorCol: Int
//        if virtualNewlines {
//            cursorCol = Int(editor_buffer_get_cursor_col_virtual(buf!, virtualNewlineLength))
//        } else {
//            cursorCol = Int(editor_buffer_get_cursor_col(buf!))
//        }
//
//        if cursorRow == row! {
//            if cursorView == nil {
//                cursorView = NSView()
//                cursorView!.wantsLayer = true
//                cursorView!.layerContentsRedrawPolicy = .onSetNeedsDisplay;
//                cursorView!.layer?.backgroundColor = CGColor(red: 0.70, green: 0.70, blue: 0.99, alpha: 1.0)
//                self.addSubview(cursorView!)
//                animateBlink(view: cursorView!)
//            }
//
//            let cellViewCoordinates = self.coordinatesForCharacter(col: cursorCol)
//
//            let newFrame = CGRect(x: cellViewCoordinates.x,
//                                  y: 0,
//                                  width: 1.6,
//                                  height: self.frame.height)
//            
//            // todo(chad): @hack (?)
//            cursorView?.layer?.zPosition = 1000
//            cursorView?.frame = newFrame
//        } else {
//            cursorView?.frame = CGRect.zero
//        }
//
//    }
//    
//    func drawSelection() {
//        let virtualNewlines = controller!.virtualNewlines
//        let virtualNewlineLength = controller!.virtualNewlineLength
//        let buf = controller?.buf
//        
//        let cursorRow: Int
//        if virtualNewlines {
//            cursorRow = Int(editor_buffer_get_cursor_row_virtual(buf!, virtualNewlineLength))
//        } else {
//            cursorRow = Int(editor_buffer_get_cursor_row(buf!))
//        }
//        
//        let cursorCol: Int
//        if virtualNewlines {
//            cursorCol = Int(editor_buffer_get_cursor_col_virtual(buf!, virtualNewlineLength))
//        } else {
//            cursorCol = Int(editor_buffer_get_cursor_col(buf!))
//        }
//        
//        // draw selection!
//        if editor_buffer_cursor_is_selection(buf!) == 0 {
//            selectionView?.frame = CGRect.zero
//            return
//        }
//
//        var selectionRow: Int
//        if virtualNewlines {
//            selectionRow = Int(editor_buffer_get_cursor_selection_start_row_virtual(buf!, virtualNewlineLength))
//        } else {
//            selectionRow = Int(editor_buffer_get_cursor_selection_start_row(buf!))
//        }
//
//        var selectionCol: Int
//        if virtualNewlines {
//            selectionCol = Int(editor_buffer_get_cursor_selection_start_col_virtual(buf!, virtualNewlineLength))
//        } else {
//            selectionCol = Int(editor_buffer_get_cursor_selection_start_col(buf!))
//        }
//
//        if cursorRow <= row! && row! <= selectionRow && cursorRow != selectionRow {
//            let rowLength: Int
//            if virtualNewlines {
//                rowLength = Int(editor_buffer_get_line_length_virtual(buf!, Int64(row!), virtualNewlineLength))
//            } else {
//                rowLength = Int(editor_buffer_get_line_length(buf!, Int64(row!)))
//            }
//
//            if row! == cursorRow {
//                drawSelectionAtPoint(startCol: cursorCol, endCol: Int(rowLength))
//            } else if row! == selectionRow {
//                drawSelectionAtPoint(startCol: 0, endCol: selectionCol)
//            } else {
//                drawSelectionAtPoint(startCol: 0, endCol: Int(rowLength))
//            }
//        } else if selectionRow <= row! && row! <= cursorRow && selectionRow != cursorRow {
//            let rowLength: Int
//            if virtualNewlines {
//                rowLength = Int(editor_buffer_get_line_length_virtual(buf!, Int64(row!), virtualNewlineLength))
//            } else {
//                rowLength = Int(editor_buffer_get_line_length(buf!, Int64(row!)))
//            }
//
//            if row! == cursorRow {
//                drawSelectionAtPoint(startCol: 0, endCol: cursorCol)
//            } else if row! == selectionRow {
//                drawSelectionAtPoint(startCol: selectionCol, endCol: Int(rowLength))
//            } else {
//                drawSelectionAtPoint(startCol: 0, endCol: Int(rowLength))
//            }
//        } else if cursorRow == selectionRow && cursorRow == row! && cursorCol < selectionCol {
//            drawSelectionAtPoint(startCol: cursorCol, endCol: selectionCol)
//        } else if cursorRow == selectionRow && cursorRow == row! && cursorCol > selectionCol {
//            drawSelectionAtPoint(startCol: selectionCol, endCol: cursorCol)
//        } else {
//            selectionView?.frame = CGRect.zero
//        }
//    }
//    
//    func drawSelectionAtPoint(startCol: Int, endCol: Int) {
//        if selectionView == nil {
//            selectionView = NSView()
//            selectionView!.wantsLayer = true
//            selectionView!.layerContentsRedrawPolicy = .onSetNeedsDisplay;
//            selectionView!.layer?.backgroundColor = CGColor(red: 0.70, green: 0.70, blue: 0.99, alpha: 1.0)
//            selectionView!.layer?.opacity = 0.4
//            selectionView!.layer?.cornerRadius = 2.0
//            selectionView!.layer?.zPosition = 1000 // todo(chad): @hack ??
//            self.addSubview(selectionView!)
//        }
//        
//        let startTableCoordinates = coordinatesForCharacter(col: startCol)
//        let endTableCoordinates = coordinatesForCharacter(col: endCol)
//        
//        let newFrame = CGRect(x: startTableCoordinates.x,
//                              y: self.textField!.frame.origin.y,
//                              width: endTableCoordinates.x - startTableCoordinates.x,
//                              height: self.frame.height)
//        
//        selectionView!.frame = newFrame
//    }
//    
//    func animateBlink(view: NSView!) {
//        let animation = CABasicAnimation(keyPath: "opacity")
//        animation.fromValue = 1.0
//        animation.toValue = 0.1
//        animation.duration = 0.6;
//        animation.autoreverses = true
//        animation.repeatCount = Float.infinity
//        cursorView!.layer?.add(animation, forKey: animation.keyPath)
//    }
    
}
