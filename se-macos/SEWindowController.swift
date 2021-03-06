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
    
    func newWindowForTab() {
        let story = self.storyboard
        let windowController: SEWindowController = story?.instantiateInitialController() as! SEWindowController
        
        self.window?.addTabbedWindow(windowController.window!, ordered: .above)
        self.subview = windowController
        
        windowController.window?.orderFront(self.window)
        windowController.window?.makeKey()
    }
    
    override func windowDidLoad() {
        self.window?.makeFirstResponder(self)
    }
    
    override func keyDown(with event: NSEvent) {
        if let vc = self.contentViewController as? SEBufferViewController {
            vc.handleKeyDown(with: event)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        self.window?.makeFirstResponder(self)
        
        if let vc = self.contentViewController as? SEBufferViewController {
            vc.handleMouseDown(with: event)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        if let vc = self.contentViewController as? SEBufferViewController {
            vc.handleMouseDragged(with: event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if let vc = self.contentViewController as? SEBufferViewController {
            vc.handleMouseUp(with: event)
        }
    }
    
}
