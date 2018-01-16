//
//  SEBufferDelegate.swift
//  se-macos
//
//  Created by Chad Russell on 8/27/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

struct Command {
    
}

struct SEEditorPreferences {
    var virtualNewlines = false
    var virtualNewlineLength: Int64 = 80
    
    var cursorBlink = true
    var cursorBlinkPeriod = 0.5
    
    var editorFont = NSFont(name: "Inconsolata", size: 16)! {
        didSet {
            charWidth = NSString(string: "0").size(withAttributes: [NSAttributedStringKey.font: editorFont]).width + 1
            charHeight = NSString(string: "p").size(withAttributes: [NSAttributedStringKey.font: editorFont]).height + 1
        }
    }
    
    var showGutter = true
    var gutterTextColor = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
    var gutterBackgroundColor = NSColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1)
    
    var editorTextColor = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
    var editorBackgroundColor = NSColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1)
    
    var footerTextColor = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
    var footerBackgroundColor = NSColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1)
    
    var cursorColor = NSColor(red: 0.7, green: 0.7, blue: 1, alpha: 1)
    var selectionColor = NSColor(red: 0.7, green: 0.7, blue: 1, alpha: 0.3)
    
    var charHeight: CGFloat = 0
    var charWidth: CGFloat = 0
    
    var tabs: String = "\t"
    var wordSeparators: String = "\n\t`~!@#$%^&*()-_=+[]{},.<>/? "
    var bigWordSeparators: String = "\n\t "
    
    var commands: [Command] = []
}

enum SEMode {
    case insert
    case normal
    case visual(line: Bool)
}

extension SEMode {
    func isVisual() -> (Bool, Bool) {
        switch self {
        case .insert:
            return (false, false)
        case .normal:
            return (false, false)
        case .visual(let line):
            return (true, line)
        }
    }
    
    func description() -> String {
        switch self {
        case .insert:
            return "--INSERT--"
        case .normal:
            return "--NORMAL--"
        case .visual(true):
            return "--VISUAL LINE--"
        case .visual(false):
            return "--VISUAL--"
        }
    }
}

protocol SEBufferDelegate {
    var preferences: SEEditorPreferences { get set }
    var mode: SEMode { get set }
    var buf: editor_buffer_t? { get set }
    var lineWidthConstraint: NSLayoutConstraint? { get }
}
