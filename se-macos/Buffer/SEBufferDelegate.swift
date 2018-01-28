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
    
    var charHeight = NSString(string: "p").size(withAttributes: [NSAttributedStringKey.font: NSFont(name: "Inconsolata", size: 16)!]).height + 1
    var charWidth = NSString(string: "0").size(withAttributes: [NSAttributedStringKey.font: NSFont(name: "Inconsolata", size: 16)!]).width + 1
    
    var tabs: String = "\t"
    var wordSeparators: String = "\n\t`~!@#$%^&*()-_=+[]{},.<>/? "
    var bigWordSeparators: String = "\n\t "
    
    var folderExcludePatterns: [String] = []
    var fileExcludePatterns: [String] = []
}

enum SEMode {
    case insert(append: Bool)
    case normal
    case visual(line: Bool)
}

extension SEMode: Equatable {
    static func ==(lhs: SEMode, rhs: SEMode) -> Bool {
        switch (lhs, rhs) {
        case (.insert(let lhsAppend), .insert(let rhsAppend)): return lhsAppend == rhsAppend
        case (.normal, .normal): return true
        case (.visual(let lhsLine), .visual(let rhsLine)): return lhsLine == rhsLine
        default: return false
        }
    }
}

extension SEMode {
    func isVisual() -> (Bool, Bool) {
        switch self {
        case .insert, .normal:
            return (false, false)
        case .visual(let line):
            return (true, line)
        }
    }
    
    func isInsert() -> Bool {
        switch self {
        case .insert(_): return true
        default: return false
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
    
    func scrollToCursor()
}
