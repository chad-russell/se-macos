//
//  Gutter.swift
//  se-macos
//
//  Created by Chad Russell on 8/25/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SEGutterView: NSView {
    
    @IBOutlet weak var width: NSLayoutConstraint!
    
    let margin: CGFloat = 3
    var delegate: SEBufferDelegate?
    
    override var isFlipped: Bool { return true }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let delegate = delegate else { return }
        let preferences = delegate.preferences
        
        self.layer?.backgroundColor = preferences.gutterBackgroundColor.cgColor
        
        let lineCount: Int64
        if preferences.virtualNewlines {
            lineCount = editor_buffer_get_line_count_virtual(delegate.buf!, preferences.virtualNewlineLength)
        } else {
            lineCount = editor_buffer_get_line_count(delegate.buf!)
        }
        
        let firstDrawableLine = Int64(floor(dirtyRect.origin.y / preferences.charHeight))
        let firstLine = max(firstDrawableLine - 2, 0)
        let lastDrawableLine = Int64(floor((dirtyRect.origin.y + dirtyRect.height) / preferences.charHeight))
        let lastLine = min(lastDrawableLine + 2, lineCount)
        
        if firstLine <= lastLine {
            for line in firstLine ..< lastLine {
                self.drawLine(line: line)
            }
        }
    }
    
    func drawLine(line: Int64) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        guard let delegate = delegate else { return }
        let preferences = delegate.preferences
        
        let y = CGFloat(line + 1) * preferences.charHeight
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1).concatenating(CGAffineTransform(translationX: margin, y: y))
        
        let stringAttributes = [NSAttributedStringKey.foregroundColor: preferences.gutterTextColor, NSAttributedStringKey.font: preferences.editorFont]
        let attributedString = NSMutableAttributedString(string: "\(line)", attributes: stringAttributes)
        let ctLine = CTLineCreateWithAttributedString(attributedString)
        
        CTLineDraw(ctLine, context)
    }
    
}
