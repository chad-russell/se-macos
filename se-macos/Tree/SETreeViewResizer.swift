//
//  SEViewResizer.swift
//  se-macos
//
//  Created by Chad Russell on 1/15/18.
//  Copyright © 2018 Chad Russell. All rights reserved.
//

import Cocoa

class SETreeViewResizer: NSView {
    
    var trackingArea = NSTrackingArea()
    
    var dragging: Bool = false
    
    var delegate: SETreeView?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrackingArea()
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        setupTrackingArea()
    }
    
    override func mouseEntered(with event: NSEvent) {
        if !dragging {
            NSCursor.resizeLeftRight.set()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if !dragging {
            NSCursor.arrow.set()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        delegate?.mouseDownX = event.locationInWindow.x
        if let constant = delegate?.delegate?.treeViewWidth.constant {
            delegate?.mouseDownWidth = constant
        }
        
        NSApplication.shared.keyWindow?.disableCursorRects()
    }
    
    override func mouseDragged(with event: NSEvent) {
        dragging = true
        if let delegate = delegate {
            if let d = delegate.delegate, d.treeViewWidth.constant <= d.treeViewMinWidth.constant {
                NSCursor.resizeRight.set()
            } else {
                NSCursor.resizeLeftRight.set()
            }
            delegate.delegate?.treeViewWidth.constant = delegate.mouseDownWidth + event.locationInWindow.x - delegate.mouseDownX
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        dragging = false
        
        if let del = delegate?.delegate {
            if del.treeViewWidth.constant < del.treeViewMinWidth.constant {
                del.treeViewWidth.constant = del.treeViewMinWidth.constant
            }
            
            del.lastTreeViewWidth = del.treeViewWidth.constant
        }
        
        NSApplication.shared.keyWindow?.enableCursorRects()
        
        let locationInSelf = self.convert(event.locationInWindow, from: nil)
        if !self.bounds.contains(locationInSelf) {
            NSCursor.arrow.set()
        } else if let d = delegate?.delegate, d.treeViewWidth.constant <= d.treeViewMinWidth.constant {
            NSCursor.resizeRight.set()
        } else {
            NSCursor.resizeLeftRight.set()
        }
        
    }
    
    func setupTrackingArea() {
        let enterExitOption: NSTrackingArea.Options = .mouseEnteredAndExited
        let activeInAppOption: NSTrackingArea.Options = .activeInActiveApp
        let trackingOptions: NSTrackingArea.Options = NSTrackingArea.Options(rawValue: enterExitOption.rawValue | activeInAppOption.rawValue)
        
        trackingArea = NSTrackingArea(rect: self.bounds, options: trackingOptions, owner: self, userInfo: nil)
        
        self.addTrackingArea(trackingArea)
    }
}
