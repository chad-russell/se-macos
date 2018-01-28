//
//  SEOutlineRowView.swift
//  se-macos
//
//  Created by Chad Russell on 1/21/18.
//  Copyright © 2018 Chad Russell. All rights reserved.
//

import Cocoa

class SEOutlineRowView: NSTableRowView {
    
    var trackingArea = NSTrackingArea()
    
    override var frame: NSRect {
        didSet {
            setupTrackingArea()
        }
    }

    func setupTrackingArea() {
        let enterExitOption: NSTrackingArea.Options = .mouseEnteredAndExited
        let activeInAppOption: NSTrackingArea.Options = .activeInActiveApp
        let trackingOptions: NSTrackingArea.Options = NSTrackingArea.Options(rawValue: enterExitOption.rawValue | activeInAppOption.rawValue)

        trackingArea = NSTrackingArea(rect: self.bounds, options: trackingOptions, owner: self, userInfo: nil)

        self.addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        if self.selectionHighlightStyle != .none {
            self.layer?.backgroundColor = OutlineItemSelection.tentative.getColor().cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        if self.selectionHighlightStyle != .none {
            self.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    override func drawSelection(in dirtyRect: NSRect) {
        if self.selectionHighlightStyle != .none {
            highlight(fillColor: OutlineItemSelection.selected.getColor())
        }
    }
    
    func highlight(fillColor: NSColor) {
        fillColor.setFill()
        
        let strokeColor = NSColor(red: fillColor.redComponent - 0.15,
                                  green: fillColor.greenComponent - 0.15,
                                  blue: fillColor.blueComponent - 0.15,
                                  alpha: 1)
        strokeColor.setStroke()
        
        let selectionPath = NSBezierPath(rect: self.bounds)
        selectionPath.fill()
        selectionPath.stroke()
    }
}
