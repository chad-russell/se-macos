//
//  SEWindow.swift
//  se-macos
//
//  Created by Chad Russell on 1/16/18.
//  Copyright © 2018 Chad Russell. All rights reserved.
//

import Cocoa

class SEWindow: NSWindow {
    
//    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
//        print("making first responder: \(responder)")
//        
//        let superReturn = super.makeFirstResponder(responder)
//        
//        var next = NSApplication.shared.keyWindow?.firstResponder
//        while next != nil {
//            print("chain: \(next)")
//            next = next?.nextResponder
//        }
//        
//        print("")
//        
//        return superReturn
//    }
    
    override var acceptsFirstResponder: Bool {
        get { return false }
    }
}
