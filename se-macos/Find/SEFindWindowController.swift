//
//  SearchWindowController.swift
//  se-macos
//
//  Created by Chad Russell on 8/24/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SEFindWindowController: NSWindowController {

    var appDelegate: AppDelegate?
    
    class func loadFromNib() -> SEFindWindowController {
        let vc = NSStoryboard(name: NSStoryboard.Name("Find"), bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("FindWindowController")) as! SEFindWindowController
        return vc
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }

}
