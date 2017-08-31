//
//  SEBufferDelegate.swift
//  se-macos
//
//  Created by Chad Russell on 8/27/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

struct SEEditorPreferences {
    var virtualNewlines = false
    var virtualNewlineLength: Int64 = 80
    
    var cursorBlink = true
    var cursorBlinkPeriod = 0.5
    
    var editorFont = NSFont(name: "Inconsolata", size: 16)!
    
    var showGutter = true
    var gutterTextColor = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
    var gutterBackgroundColor = NSColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1)
    
    var editorTextColor = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
    var editorBackgroundColor = NSColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1)
    
    var cursorColor = NSColor(red: 0.7, green: 0.7, blue: 1, alpha: 1)
    var selectionColor = NSColor(red: 0.7, green: 0.7, blue: 1, alpha: 0.3)
    
    func charHeight() -> CGFloat {
        return NSString(string: "p").size(withAttributes: [NSAttributedStringKey.font: editorFont]).height + 1
    }
    func charWidth() -> CGFloat {
        return NSString(string: "0").size(withAttributes: [NSAttributedStringKey.font: editorFont]).width + 1
    }
}

enum SEMode {
    case insert
    case normal
}

protocol SEBufferDelegate {
    var preferences: SEEditorPreferences { get set }
    var mode: SEMode { get set }
    var buf: editor_buffer_t? { get set }
    var lineWidthConstraint: NSLayoutConstraint? { get }
}
