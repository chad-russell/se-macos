//
//  SEWindowController.swift
//  se-macos
//
//  Created by Chad Russell on 8/12/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SEWindowController: NSWindowController {
    
    var subview: SEWindowController?
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    @IBAction override func newWindowForTab(_ sender: Any?) {
        let story = self.storyboard
        let windowController: SEWindowController = story?.instantiateInitialController() as! SEWindowController
        
        self.window?.addTabbedWindow(windowController.window!, ordered: .above)
        self.subview = windowController
        
        windowController.window?.orderFront(self.window)
        windowController.window?.makeKey()
    }
    
}
