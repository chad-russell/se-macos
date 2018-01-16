//
//  FindViewController.swift
//  se-macos
//
//  Created by Chad Russell on 8/24/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SEFindViewController: NSViewController {

    @IBOutlet weak var searchTextField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    @IBAction func search(_ sender: Any) {
        let currentWindowController = NSApplication.shared.mainWindow?.windowController as? SEFindWindowController
        currentWindowController?.currentEditor?.search(searchTextField.stringValue)
    }
    
    @IBAction func searchBackward(_ sender: Any) {
        let currentWindowController = NSApplication.shared.mainWindow?.windowController as? SEFindWindowController
        currentWindowController?.currentEditor?.searchBackward(searchTextField.stringValue)
    }
    
}
