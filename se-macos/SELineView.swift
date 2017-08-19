//
//  SELineView.swift
//  se-macos
//
//  Created by Chad Russell on 8/12/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SELineView: NSView {
    
    @IBOutlet weak var lineNumberView: NSTextField!
    @IBOutlet weak var textView: NSTextField!
    
    var controller: SETextTableViewController?
    
    var selectionViews: [NSView] = []
    var cursorViews: [NSView] = []
    
    var row: Int = -1 {
        didSet {
            let maxRows: Int
            if controller!.virtualNewlines {
                maxRows = Int(editor_buffer_get_line_count_virtual(controller!.buf!, controller!.virtualNewlineLength))
            } else {
                maxRows = Int(editor_buffer_get_line_count(controller!.buf!))
            }
            
            if row >= 0 && row < maxRows {
                lineNumberView.stringValue = "\(row)"
                reload()
            } else {
                lineNumberView.stringValue = ""
                textView.stringValue = ""
            }
        }
    }
    
    func reload() {
        lineNumberView.textColor = controller!.lineNumberColor
        textView.textColor = controller!.textColor
        
        lineNumberView.font = controller?.seFont
        textView.font = controller?.seFont
        
        let row64 = Int64(row)

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
        let bufBytes = editor_buffer_get_buf_bytes(stringBuf)
        if bufBytes != nil {
            let swiftString = String(cString: bufBytes!)
            textView.stringValue = swiftString
        }

        layoutSubtreeIfNeeded()

        let cursorCount = editor_buffer_get_cursor_count(controller!.buf!)

        if Int(cursorCount) != cursorViews.count {
            cursorViews.forEach({ (view: NSView) in
                view.removeFromSuperview()
            })
            cursorViews = []

            for _ in 0..<cursorCount {
                let cursorView = NSView()
                cursorView.wantsLayer = true
                cursorView.layerContentsRedrawPolicy = .onSetNeedsDisplay;
                animateBlink(view: cursorView)

                self.addSubview(cursorView)
                cursorViews.append(cursorView)
            }
        }

        if Int(cursorCount) != selectionViews.count {
            selectionViews.forEach({ (view: NSView) in
                view.removeFromSuperview()
            })
            selectionViews = []

            for _ in 0..<cursorCount {
                let selectionView = NSView()
                selectionView.wantsLayer = true
                selectionView.layerContentsRedrawPolicy = .onSetNeedsDisplay;
                selectionView.layer?.opacity = 0.4
                selectionView.layer?.cornerRadius = 2.0
                selectionView.layer?.zPosition = 1000 // todo(chad): @hack ??

                self.addSubview(selectionView)
                selectionViews.append(selectionView)
            }
        }

        for cursorIdx in 0..<cursorCount {
            drawCursor(cursorIdx: cursorIdx, cursorView: cursorViews[Int(cursorIdx)])
            drawSelection(cursorIdx: cursorIdx)
        }
    }
    
    func drawCursor(cursorIdx: Int64, cursorView: NSView) {
        // draw cursor!
        let virtualNewlines = controller!.virtualNewlines
        let virtualNewlineLength = controller!.virtualNewlineLength
        let buf = controller?.buf
        
        let cursorRow: Int
        if virtualNewlines {
            cursorRow = Int(editor_buffer_get_cursor_row_virtual(buf!, cursorIdx, virtualNewlineLength))
        } else {
            cursorRow = Int(editor_buffer_get_cursor_row(buf!, cursorIdx))
        }
        
        let cursorCol: Int
        if virtualNewlines {
            cursorCol = Int(editor_buffer_get_cursor_col_virtual(buf!, cursorIdx, virtualNewlineLength))
        } else {
            cursorCol = Int(editor_buffer_get_cursor_col(buf!, cursorIdx))
        }
        
        if cursorRow == row {
            cursorView.layer?.backgroundColor = controller!.cursorColor.cgColor
            
            let cellViewCoordinates = self.coordinatesForCharacter(col: cursorCol)
            
            let newFrame = CGRect(x: cellViewCoordinates.x,
                                  y: 0,
                                  width: 1.6,
                                  height: self.frame.height)
            
            // todo(chad): @hack (?)
            cursorView.layer?.zPosition = 1000
            cursorView.frame = newFrame
            
            controller!.cursorView = cursorView
        } else {
            cursorView.frame = CGRect.zero
        }
        
    }
    
    func coordinatesForCharacter(col: Int) -> CGPoint {
        let textStorage = NSTextStorage(string: self.textView!.stringValue)
        
        // todo(chad): @hack ??
        let textContainer = NSTextContainer(size: CGSize(width: 1000000, height: self.frame.size.height))
        
        let layoutManager = NSLayoutManager()
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        textStorage.addAttribute(NSAttributedStringKey.font, value: self.textView!.font!, range: NSRange(location: 0, length: textStorage.length))
        textContainer.lineFragmentPadding = 0
        
        layoutManager.ensureLayout(for: textContainer)
        
        var glyph = 0
        for _ in 0..<col {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: glyph, length: 1), actualCharacterRange: nil)
            glyph += glyphRange.length
        }
        
        var boundingRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
        if boundingRect.width == 0 {
            boundingRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph - 1, length: 1), in: textContainer)
            boundingRect.origin.x += boundingRect.width
        }
        
        // todo(chad): + 2 seems like a hack??
        let localCoordinates = CGPoint(x: self.textView!.frame.origin.x + boundingRect.origin.x + 2,
                                       y: self.frame.height)
        return localCoordinates
    }
    
    func colForCharAt(point: NSPoint) -> Int {
        let textStorage = NSTextStorage(string: self.textView!.stringValue)
        let textContainer = NSTextContainer(size: self.textView!.bounds.size)
        let layoutManager = NSLayoutManager()

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        textStorage.addAttribute(NSAttributedStringKey.font, value: self.textView!.font!, range: NSRange(location: 0, length: textStorage.length))
        textContainer.lineFragmentPadding = 0

        layoutManager.ensureLayout(for: textContainer)

        let pointInTextField = NSPoint(x: point.x - self.textView!.frame.origin.x, y: point.y - self.textView!.frame.origin.y)

        let glyphIndex = layoutManager.glyphIndex(for: pointInTextField, in: textContainer)

        let boundingRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)

        if pointInTextField.x > boundingRect.origin.x + boundingRect.width * 3 / 4 {
            return glyphIndex + 1
        }

        return glyphIndex
    }
    
    func drawSelection(cursorIdx: Int64) {
        let virtualNewlines = controller!.virtualNewlines
        let virtualNewlineLength = controller!.virtualNewlineLength
        let buf = controller?.buf
        
        let selectionView = self.selectionViews[Int(cursorIdx)]
        
        if (editor_buffer_cursor_is_selection(buf!, cursorIdx) == 0) {
            selectionView.frame = CGRect.zero
            return
        }
        
        let cursorRow: Int
        if virtualNewlines {
            cursorRow = Int(editor_buffer_get_cursor_row_virtual(buf!, cursorIdx, virtualNewlineLength))
        } else {
            cursorRow = Int(editor_buffer_get_cursor_row(buf!, cursorIdx))
        }
        
        let cursorCol: Int
        if virtualNewlines {
            cursorCol = Int(editor_buffer_get_cursor_col_virtual(buf!, cursorIdx, virtualNewlineLength))
        } else {
            cursorCol = Int(editor_buffer_get_cursor_col(buf!, cursorIdx))
        }
        
        // draw selection!
        if editor_buffer_cursor_is_selection(buf!, cursorIdx) == 0 {
            selectionView.frame = CGRect.zero
            return
        }
        
        var selectionRow: Int
        if virtualNewlines {
            selectionRow = Int(editor_buffer_get_cursor_selection_start_row_virtual(buf!, cursorIdx, virtualNewlineLength))
        } else {
            selectionRow = Int(editor_buffer_get_cursor_selection_start_row(buf!, cursorIdx))
        }
        
        var selectionCol: Int
        if virtualNewlines {
            selectionCol = Int(editor_buffer_get_cursor_selection_start_col_virtual(buf!, cursorIdx, virtualNewlineLength))
        } else {
            selectionCol = Int(editor_buffer_get_cursor_selection_start_col(buf!, cursorIdx))
        }
        
        if cursorRow <= row && row <= selectionRow && cursorRow != selectionRow {
            let rowLength: Int
            if virtualNewlines {
                rowLength = Int(editor_buffer_get_line_length_virtual(buf!, Int64(row), virtualNewlineLength))
            } else {
                rowLength = Int(editor_buffer_get_line_length(buf!, Int64(row)))
            }
            
            if row == cursorRow {
                drawSelectionAtPoint(startCol: cursorCol, endCol: Int(rowLength), selectionView: selectionView)
            } else if row == selectionRow {
                drawSelectionAtPoint(startCol: 0, endCol: selectionCol, selectionView: selectionView)
            } else {
                drawSelectionAtPoint(startCol: 0, endCol: Int(rowLength), selectionView: selectionView)
            }
        } else if selectionRow <= row && row <= cursorRow && selectionRow != cursorRow {
            let rowLength: Int
            if virtualNewlines {
                rowLength = Int(editor_buffer_get_line_length_virtual(buf!, Int64(row), virtualNewlineLength))
            } else {
                rowLength = Int(editor_buffer_get_line_length(buf!, Int64(row)))
            }
            
            if row == cursorRow {
                drawSelectionAtPoint(startCol: 0, endCol: cursorCol, selectionView: selectionView)
            } else if row == selectionRow {
                drawSelectionAtPoint(startCol: selectionCol, endCol: Int(rowLength), selectionView: selectionView)
            } else {
                drawSelectionAtPoint(startCol: 0, endCol: Int(rowLength), selectionView: selectionView)
            }
        } else if cursorRow == selectionRow && cursorRow == row && cursorCol < selectionCol {
            drawSelectionAtPoint(startCol: cursorCol, endCol: selectionCol, selectionView: selectionView)
        } else if cursorRow == selectionRow && cursorRow == row && cursorCol > selectionCol {
            drawSelectionAtPoint(startCol: selectionCol, endCol: cursorCol, selectionView: selectionView)
        } else {
            selectionView.frame = CGRect.zero
        }
    }
    
    func drawSelectionAtPoint(startCol: Int, endCol: Int, selectionView: NSView) {
        selectionView.layer?.backgroundColor = controller!.selectionColor.cgColor
        
        let startTableCoordinates = coordinatesForCharacter(col: startCol)
        let endTableCoordinates = coordinatesForCharacter(col: endCol)
        
        let newFrame = CGRect(x: startTableCoordinates.x,
                              y: self.textView!.frame.origin.y,
                              width: endTableCoordinates.x - startTableCoordinates.x,
                              height: self.frame.height)
        
        selectionView.frame = newFrame
    }
    
    func animateBlink(view: NSView!) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.1
        animation.duration = 0.6;
        animation.autoreverses = true
        animation.repeatCount = Float.infinity
        view.layer?.add(animation, forKey: animation.keyPath)
    }
    
    override func mouseDown(with event: NSEvent) {
        let locationInSelf = self.convert(event.locationInWindow, from: nil)
        let clickedCol = colForCharAt(point: locationInSelf)
        
        if event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
            if controller!.virtualNewlines {
                editor_buffer_add_cursor_at_point_virtual(controller!.buf!, Int64(row), Int64(clickedCol), controller!.virtualNewlineLength)
            } else {
                editor_buffer_add_cursor_at_point(controller!.buf!, Int64(row), Int64(clickedCol))
            }
        } else if event.modifierFlags.contains(NSEvent.ModifierFlags.shift) {
            editor_buffer_set_cursor_is_selection(controller!.buf!, 1)
            
            if controller!.virtualNewlines {
                editor_buffer_set_cursor_point_virtual(controller!.buf!, Int64(row), Int64(clickedCol), controller!.virtualNewlineLength)
            } else {
                editor_buffer_set_cursor_point(controller!.buf!, Int64(row), Int64(clickedCol))
            }
        } else {
            editor_buffer_clear_cursors(controller!.buf!)
            
            if controller!.virtualNewlines {
                editor_buffer_add_cursor_at_point_virtual(controller!.buf!, Int64(row), Int64(clickedCol), controller!.virtualNewlineLength)
            } else {
                editor_buffer_add_cursor_at_point(controller!.buf!, Int64(row), Int64(clickedCol))
            }
        }
        
        controller!.reload()
    }
    
    override func mouseDragged(with event: NSEvent) {
        Swift.print("mouse dragged! row: \(row)")
    }

}
