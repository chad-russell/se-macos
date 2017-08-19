//
//  SETableView.swift
//  se-macos
//
//  Created by Chad Russell on 7/25/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SETableView : NSTableView {

    var controller: SETextTableViewController!
    
    override func keyDown(with event: NSEvent) {
        self.nextResponder?.keyDown(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        self.nextResponder?.mouseDown(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        self.nextResponder?.mouseDragged(with: event)
    }

}
