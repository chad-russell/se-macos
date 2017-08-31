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

    var currentEditor: SEBufferViewController? {
        return NSApplication.shared.mainWindow?.contentViewController as? SEBufferViewController
    }
    var currentFindWindowController: SEFindWindowController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @IBAction func seSave(sender: NSMenuItem) {
        currentEditor?.save()
    }
    
    @IBAction func seSaveAs(sender: NSMenuItem) {
        currentEditor?.saveAs()
    }
    
    @IBAction func seOpen(_ sender: Any) {
        currentEditor?.openFile()
    }
    
    @IBAction func seFind(_ sender: Any) {
        if currentFindWindowController == nil {
            currentFindWindowController = SEFindWindowController.loadFromNib()
        }
        currentFindWindowController?.showWindow(self)
    }
    
    @IBAction func seChooseFont(sender: NSMenuItem) {
        currentEditor?.chooseFont(sender)
    }
    
    @IBAction func seIncreaseFontSize(_ sender: Any) {
        currentEditor?.increaseFontSize()
    }
    
    @IBAction func seDecreaseFontSize(_ sender: Any) {
        currentEditor?.decreaseFontSize()
    }
    
    @IBAction func newWindowForTab(_ sender: Any?) {
        if let wc = NSApplication.shared.mainWindow?.windowController as? SEWindowController {
            wc.newWindowForTab()
        }
    }
}

