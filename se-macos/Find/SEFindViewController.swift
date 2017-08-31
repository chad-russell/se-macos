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
        let appDelegate = NSApplication.shared.delegate as? AppDelegate
        appDelegate?.currentEditor?.search(searchTextField.stringValue)
    }
    
}
