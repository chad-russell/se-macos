//
//  SEWindow.swift
//  se-macos
//
//  Created by Chad Russell on 1/11/18.
//  Copyright © 2018 Chad Russell. All rights reserved.
//

import Cocoa

class SEWindow: NSWindow {
    
    override func keyDown(with event: NSEvent) {
        if let wc = self.windowController as? SEWindowController {
            wc.keyDown(with: event)
        }
    }
}
