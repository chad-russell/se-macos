//
//  SEWindow.swift
//  se-macos
//
//  Created by Chad Russell on 1/16/18.
//  Copyright © 2018 Chad Russell. All rights reserved.
//

import Cocoa

class SEWindow: NSWindow {
    
    override var acceptsFirstResponder: Bool {
        get { return false }
    }
}
