//
//  SEEditorView.swift
//  se-macos
//
//  Created by Chad Russell on 8/21/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SEEditorView: NSView {

    var delegate: SEBufferDelegate?
    var cursorRects: [CGRect] = []
    var cursorLayerParent = CALayer()
    var cursorLayers: [CAShapeLayer] = []
    var cursorAnimation = CABasicAnimation(keyPath: "opacity")
    var showCursor = true
    var longestLine: CGFloat = 0
    
    override var isFlipped: Bool { return true }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        
        self.wantsLayer = true
        self.layer!.addSublayer(cursorLayerParent)
        cursorAnimation.fromValue = 1
        cursorAnimation.toValue = 0.2
        cursorAnimation.repeatCount = Float.infinity
        cursorAnimation.autoreverses = true
        cursorLayerParent.add(cursorAnimation, forKey: "opacity")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let layer = self.layer else { return }
        guard let delegate = delegate else { return }
        let preferences = delegate.preferences
        
        layer.backgroundColor = preferences.editorBackgroundColor.cgColor
        
        let lineCount: Int64
        if preferences.virtualNewlines {
            lineCount = editor_buffer_get_line_count_virtual(delegate.buf!, preferences.virtualNewlineLength)
        } else {
            lineCount = editor_buffer_get_line_count(delegate.buf!)
        }
        
        while self.cursorLayers.count < editor_buffer_get_cursor_count(delegate.buf!) {
            let newLayer = CAShapeLayer()
            self.cursorLayers.append(newLayer)
            cursorLayerParent.addSublayer(newLayer)
        }
        while self.cursorLayers.count > editor_buffer_get_cursor_count(delegate.buf!) {
            self.cursorLayers.removeLast()
            cursorLayerParent.sublayers?.removeLast()
        }
        
        let firstDrawableLine = Int64(floor(dirtyRect.origin.y / preferences.charHeight))
        let firstLine = max(firstDrawableLine - 2, 0)
        let lastDrawableLine = Int64(floor((dirtyRect.origin.y + dirtyRect.height) / preferences.charHeight))
        let lastLine = min(lastDrawableLine + 2, lineCount)
        if firstLine <= lastLine {
            for line in firstLine ... lastLine {
                self.drawLine(line: line)
            }
        }
        
        // change cursor animation settings if we need
        if cursorAnimation.duration != preferences.cursorBlinkPeriod {
            cursorLayerParent.removeAnimation(forKey: "opacity")
            cursorAnimation.duration = preferences.cursorBlinkPeriod
            cursorLayerParent.add(cursorAnimation, forKey: "opacity")
        }
        if !preferences.cursorBlink {
            cursorLayerParent.removeAnimation(forKey: "opacity")
        } else if cursorLayerParent.animation(forKey: "opacity") == nil {
            cursorLayerParent.add(cursorAnimation, forKey: "opacity")
        }
    }
    
    func drawLine(line: Int64, scrollToCursor: Bool = false) {
        guard let delegate = delegate else { return }
        let preferences = delegate.preferences
        let charHeight = preferences.charHeight
        
        let context = NSGraphicsContext.current?.cgContext
        
        let stringBuf: OpaquePointer!
        if preferences.virtualNewlines {
            stringBuf = editor_buffer_get_text_between_points_virtual(delegate.buf!, line, 0, line + 1, 0, preferences.virtualNewlineLength)
        } else {
            stringBuf = editor_buffer_get_text_between_points(delegate.buf!, line, 0, line + 1, 0)
        }
        defer {
            editor_buffer_free_buf(stringBuf)
        }
        guard let bufBytes = editor_buffer_get_buf_bytes(stringBuf) else {
            return
        }
        let swiftString = String(cString: bufBytes)
        
        let x: CGFloat = 3
        let y = CGFloat(line + 1) * preferences.charHeight
        let cursorY = y + 4
        context?.textMatrix = CGAffineTransform(scaleX: 1, y: -1).concatenating(CGAffineTransform(translationX: x, y: y))
        
        let stringAttributes = [NSAttributedStringKey.foregroundColor: preferences.editorTextColor, NSAttributedStringKey.font: preferences.editorFont]
        let attributedString = NSMutableAttributedString(string: swiftString, attributes: stringAttributes)
        let ctLine = CTLineCreateWithAttributedString(attributedString)
        
        if !scrollToCursor {
            CTLineDraw(ctLine, context!)
        }
        
        let cursorCount = editor_buffer_get_cursor_count(delegate.buf!)
        for cursorIdx in 0 ..< cursorCount {
            let cursorRow: Int64
            let cursorCol: Int64
            
            if preferences.virtualNewlines {
                cursorRow = editor_buffer_get_cursor_row_virtual(delegate.buf!, cursorIdx, preferences.virtualNewlineLength)
                cursorCol = editor_buffer_get_cursor_col_virtual(delegate.buf!, cursorIdx, preferences.virtualNewlineLength)
            } else {
                cursorRow = editor_buffer_get_cursor_row(delegate.buf!, cursorIdx)
                cursorCol = editor_buffer_get_cursor_col(delegate.buf!, cursorIdx)
            }
            
            let selection = editor_buffer_cursor_is_selection(delegate.buf!, cursorIdx) == 1
            
            if selection {
                var selectionRect: CGRect? = nil
                context?.setFillColor(preferences.selectionColor.cgColor)

                var cursorSelectionCol: Int64
                var cursorSelectionRow: Int64
                
                var realCursorCol = cursorCol

                if preferences.virtualNewlines {
                    cursorSelectionCol = editor_buffer_get_cursor_selection_start_col_virtual(delegate.buf!, cursorIdx, preferences.virtualNewlineLength)
                    cursorSelectionRow = editor_buffer_get_cursor_selection_start_row_virtual(delegate.buf!, cursorIdx, preferences.virtualNewlineLength)
                } else {
                    cursorSelectionCol = editor_buffer_get_cursor_selection_start_col(delegate.buf!, cursorIdx)
                    cursorSelectionRow = editor_buffer_get_cursor_selection_start_row(delegate.buf!, cursorIdx)
                }
                
                let (isVisual, isLine) = delegate.mode.isVisual()
                if isVisual && isLine {
                    if cursorRow <= cursorSelectionRow {
                        let lastCol: Int64
                        if preferences.virtualNewlines {
                            lastCol = editor_buffer_get_line_length_virtual(delegate.buf!, cursorSelectionRow, preferences.virtualNewlineLength)
                        } else {
                            lastCol = editor_buffer_get_line_length(delegate.buf!, cursorSelectionRow)
                        }
                        
                        realCursorCol = 0
                        cursorSelectionCol = lastCol
                    } else if cursorRow > cursorSelectionRow {
                        let lastCol: Int64
                        if preferences.virtualNewlines {
                            lastCol = editor_buffer_get_line_length_virtual(delegate.buf!, cursorRow, preferences.virtualNewlineLength)
                        } else {
                            lastCol = editor_buffer_get_line_length(delegate.buf!, cursorRow)
                        }
                        
                        realCursorCol = lastCol
                        cursorSelectionCol = 0
                    }
                }

                if cursorRow == line {
                    if cursorRow == cursorSelectionRow {
                        let startOffset = CTLineGetOffsetForStringIndex(ctLine, CFIndex(realCursorCol), nil)
                        let endOffset = CTLineGetOffsetForStringIndex(ctLine, CFIndex(cursorSelectionCol), nil)
                        selectionRect = CGRect(x: x + startOffset, y: cursorY - charHeight, width: endOffset - startOffset, height: charHeight)
                    } else if cursorSelectionRow > cursorRow {
                        let startOffset = CTLineGetOffsetForStringIndex(ctLine, CFIndex(realCursorCol), nil)

                        let lastCol: Int64
                        if preferences.virtualNewlines {
                            lastCol = editor_buffer_get_line_length_virtual(delegate.buf!, cursorRow, preferences.virtualNewlineLength)
                        } else {
                            lastCol = editor_buffer_get_line_length(delegate.buf!, cursorRow)
                        }

                        let endOffset = CTLineGetOffsetForStringIndex(ctLine, CFIndex(lastCol), nil)
                        selectionRect = CGRect(x: x + startOffset, y: cursorY - charHeight, width: endOffset - startOffset, height: charHeight)
                    } else {
                        let startOffset = CTLineGetOffsetForStringIndex(ctLine, CFIndex(realCursorCol), nil)
                        let endOffset = CTLineGetOffsetForStringIndex(ctLine, 0, nil)
                        selectionRect = CGRect(x: x + startOffset, y: cursorY - charHeight, width: endOffset - startOffset, height: charHeight)
                    }
                } else if cursorSelectionRow == line {
                    if cursorSelectionRow > cursorRow {
                        let startOffset = CTLineGetOffsetForStringIndex(ctLine, CFIndex(cursorSelectionCol), nil)
                        let endOffset = CTLineGetOffsetForStringIndex(ctLine, 0, nil)
                        selectionRect = CGRect(x: x + startOffset, y: cursorY - charHeight, width: endOffset - startOffset, height: charHeight)
                    } else {
                        let startOffset = CTLineGetOffsetForStringIndex(ctLine, CFIndex(cursorSelectionCol), nil)

                        let lastCol: Int64
                        if preferences.virtualNewlines {
                            lastCol = editor_buffer_get_line_length_virtual(delegate.buf!, cursorSelectionRow, preferences.virtualNewlineLength)
                        } else {
                            lastCol = editor_buffer_get_line_length(delegate.buf!, cursorSelectionRow)
                        }

                        let endOffset = CTLineGetOffsetForStringIndex(ctLine, CFIndex(lastCol), nil)
                        selectionRect = CGRect(x: x + startOffset, y: cursorY - charHeight, width: endOffset - startOffset, height: charHeight)
                    }
                } else if (cursorRow < line && cursorSelectionRow > line) || (cursorRow > line && cursorSelectionRow < line) {
                    let startOffset = CTLineGetOffsetForStringIndex(ctLine, 0, nil)

                    let lastCol: Int64
                    if preferences.virtualNewlines {
                        lastCol = editor_buffer_get_line_length_virtual(delegate.buf!, line, preferences.virtualNewlineLength)
                    } else {
                        lastCol = editor_buffer_get_line_length(delegate.buf!, line)
                    }

                    let endOffset = CTLineGetOffsetForStringIndex(ctLine, CFIndex(lastCol), nil)
                    selectionRect = CGRect(x: x + startOffset, y: cursorY - charHeight, width: endOffset - startOffset, height: charHeight)
                }

                if selectionRect != nil && !scrollToCursor {
                    if showCursor {
                        context?.fill(selectionRect!)
                    }
                }
            }
            
            // single cursor. If it's not on this row then continue
            if cursorRow == line {
                context?.setFillColor(preferences.cursorColor.cgColor)
                
                let startOffset = CTLineGetOffsetForStringIndex(ctLine, CFIndex(cursorCol), nil)
                var width: CGFloat
                switch delegate.mode {
                case .insert: width = 1.5
                case .visual:
                    fallthrough
                case .normal:
                    let endOffset = CTLineGetOffsetForStringIndex(ctLine, CFIndex(cursorCol + 1), nil)
                    width = endOffset - startOffset
                    if width == 0 {
                        width = NSString(string: "0").size(withAttributes: [NSAttributedStringKey.font: preferences.editorFont]).width
                    }
                }
                let cursorRect = CGRect(x: x + startOffset, y: cursorY - charHeight, width: width, height: charHeight)
                self.cursorRects.append(cursorRect)
                
                while cursorLayers.count <= cursorIdx {
                    let newLayer = CAShapeLayer()
                    cursorLayers.append(newLayer)
                    self.cursorLayerParent.addSublayer(newLayer)
                }
                let cursorLayer = cursorLayers[Int(cursorIdx)]
                cursorLayer.path = CGPath(rect: cursorRect, transform: nil)
                cursorLayer.lineWidth = 0.5
                let cursorColor = showCursor ? preferences.cursorColor.cgColor : NSColor.clear.cgColor
                cursorLayer.strokeColor = cursorColor
                cursorLayer.fillColor = cursorColor
                cursorLayer.bounds = cursorRect
                cursorLayer.position = CGPoint(x: cursorRect.origin.x + cursorRect.width / 2, y: cursorRect.origin.y + cursorRect.height / 2)
            }
        }
    }
    
    func mouseDownHelper(event: NSEvent, drag: Bool = false) {
        guard let delegate = delegate else { return }
        let preferences = delegate.preferences
        
        let clickedPoint = self.convert(event.locationInWindow, from: nil)
        let clickedLine = Int64(floor(clickedPoint.y / preferences.charHeight))

        let stringBuf: OpaquePointer!
        if preferences.virtualNewlines {
            stringBuf = editor_buffer_get_text_between_points_virtual(delegate.buf!, clickedLine, 0, clickedLine + 1, 0, preferences.virtualNewlineLength)
        } else {
            stringBuf = editor_buffer_get_text_between_points(delegate.buf!, clickedLine, 0, clickedLine + 1, 0)
        }
        defer {
            editor_buffer_free_buf(stringBuf)
        }
        guard let bufBytes = editor_buffer_get_buf_bytes(stringBuf) else {
            return
        }
        let swiftString = String(cString: bufBytes)
        
        let stringAttributes = [NSAttributedStringKey.foregroundColor: preferences.editorTextColor, NSAttributedStringKey.font: preferences.editorFont]
        let attributedString = NSAttributedString(string: swiftString, attributes: stringAttributes)
        let ctLine = CTLineCreateWithAttributedString(attributedString)

        let gutterOffset: CGFloat = 3
        let clickedCol = CTLineGetStringIndexForPosition(ctLine, CGPoint(x: clickedPoint.x - gutterOffset, y: 0))

        if event.modifierFlags.contains(.command) {
            if !drag {
                if preferences.virtualNewlines {
                    editor_buffer_add_cursor_at_point_virtual(delegate.buf!, clickedLine, Int64(clickedCol), preferences.virtualNewlineLength)
                } else {
                    editor_buffer_add_cursor_at_point(delegate.buf!, clickedLine, Int64(clickedCol))
                }
            }
        } else {
            if drag || event.modifierFlags.contains(.shift) {
                editor_buffer_set_cursor_is_selection(delegate.buf!, 1)
                
                if preferences.virtualNewlines {
                    editor_buffer_set_cursor_point_virtual(delegate.buf!, clickedLine, Int64(clickedCol), preferences.virtualNewlineLength)
                } else {
                    editor_buffer_set_cursor_point(delegate.buf!, clickedLine, Int64(clickedCol))
                }
                
                for cursorIdx in 0..<editor_buffer_get_cursor_count(delegate.buf!) {
                    let pos = editor_buffer_get_cursor_pos(delegate.buf!, cursorIdx)
                    let selectionPos = editor_buffer_get_cursor_selection_start_pos(delegate.buf!, cursorIdx)
                    
                    if pos == selectionPos {
                        editor_buffer_set_cursor_is_selection_for_cursor_index(delegate.buf!, cursorIdx, 0)
                    }
                }
            } else if preferences.virtualNewlines {
                editor_buffer_set_cursor_is_selection(delegate.buf!, 0)
                editor_buffer_set_cursor_point_virtual(delegate.buf!, clickedLine, Int64(clickedCol), preferences.virtualNewlineLength)
            } else {
                editor_buffer_set_cursor_is_selection(delegate.buf!, 0)
                editor_buffer_set_cursor_point(delegate.buf!, clickedLine, Int64(clickedCol))
            }
            
            sort_and_merge_cursors(delegate.buf!)
        }
        
        self.needsDisplay = true
    }
}
