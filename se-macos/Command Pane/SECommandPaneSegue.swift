//
//  CommandPaneSegue.swift
//  se-macos
//
//  Created by Chad Russell on 8/28/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class CommandPaneSegueAnimator: NSObject, NSViewControllerPresentationAnimator {
    @objc func animatePresentation(of viewController: NSViewController, from fromViewController: NSViewController) {
        let editorVC = fromViewController as! SEBufferViewController
        
        let commandVC = viewController as! SECommandPaneViewController
        commandVC.view.wantsLayer = true
        commandVC.view.layerContentsRedrawPolicy = .onSetNeedsDisplay
        commandVC.view.alphaValue = 0
        editorVC.view.addSubview(commandVC.view)
        commandVC.view.frame = NSRectFromCGRect(editorVC.view.frame)
        commandVC.view.layer?.backgroundColor = NSColor.gray.cgColor
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            context.duration = 0.1
            commandVC.view.animator().alphaValue = 0.8
        }, completionHandler: nil)
        
        editorVC.commandViewController = commandVC
        commandVC.bufferVC = editorVC
        commandVC.reload()
    }
    
    @objc func animateDismissal(of viewController: NSViewController, from fromViewController: NSViewController) {
        let commandVC = viewController as! SECommandPaneViewController
        commandVC.view.wantsLayer = true
        commandVC.view.layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            context.duration = 0.1
            commandVC.view.animator().alphaValue = 0
        }, completionHandler: {
            commandVC.view.removeFromSuperview()
        })
    }
}

class SECommandPaneSegue: NSStoryboardSegue {
    override func perform() {
        let animator = CommandPaneSegueAnimator()
        let sourceVC  = self.sourceController as! NSViewController
        let destVC = self.destinationController as! NSViewController
        sourceVC.presentViewController(destVC, animator: animator)
    }
}
