//
//  AppDelegate.swift
//  se-macos
//
//  Created by Chad Russell on 4/21/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @objc
    @IBAction func seSave(sender: NSMenuItem) {
        // override this in the view controller
    }
    
    @objc
    @IBAction func seSaveAs(sender: NSMenuItem) {
        // override this in the view controller
    }
    
    @objc
    @IBAction func seOpen(sender: NSMenuItem) {
        // override this in the view controller
    }
    
    @objc
    @IBAction func seChooseFont(sender: NSMenuItem) {
        // override this in the view controller
    }
    
    @objc
    @IBAction func seIncreaseFontSize(sender: NSMenuItem) {
        // override this in the view controller
    }
    
    @objc
    @IBAction func seDecreaseFontSIze(sender: NSMenuItem) {
        // override this in the view controller
    }
    
    @objc
    @IBAction func newWindowForTab(_ sender: Any?) { }
}

