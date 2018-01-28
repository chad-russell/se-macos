//
//  JumpToLocationCommandDelegate.swift
//  se-macos
//
//  Created by Chad Russell on 1/20/18.
//  Copyright © 2018 Chad Russell. All rights reserved.
//

import Cocoa

class JumpToLocationCommandDelegate: CommandDelegate {
    
    var delegate: SECommandPaneViewController
    var pattern: String = ""
    
    var title: String = "Jump to Location (line[:col])"
    
    init(delegate: SECommandPaneViewController) {
        self.delegate = delegate
    }
    
    func refreshTableview(_ pattern: String) -> [TableViewItem] {
        self.pattern = pattern
        return []
    }
    
    func select(_ selectedItemIndex: Int) {
        defer { self.delegate.bufferVC?.hideCommandView() }
        
        let split = pattern.split(separator: ":")
        if split.count != 1 && split.count != 2 {
            return
        }
        
        guard let line = Int64(split[0]) else { return }
        
        let col: Int64
        if split.count == 2 {
            guard let parsedCol = Int64(split[1]) else { return }
            col = parsedCol
        } else {
            col = 0
        }
        
        if let preferences = self.delegate.bufferVC?.preferences,
        let buf = self.delegate.bufferVC?.buf {
            if preferences.virtualNewlines {
                editor_buffer_set_cursor_point_virtual(buf, line, col, preferences.virtualNewlineLength)
            } else {
                editor_buffer_set_cursor_point(buf, line, col)
            }
            
            self.delegate.bufferVC?.reload()
        }
    }
    
}
