//
//  SECommandPaneView.swift
//  se-macos
//
//  Created by Chad Russell on 8/27/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SECommandPaneView: NSView {
    
    static let inset: CGFloat = 3
    
    override func draw(_ dirtyRect: NSRect) {
        if let context = NSGraphicsContext.current?.cgContext {
            let inset = SECommandPaneView.inset
            let radius: CGFloat = inset
            let insetBounds = NSRect.init(x: self.bounds.origin.x + inset, y: self.bounds.origin.y + inset, width: self.bounds.width - 2 * inset, height: self.bounds.height - 2 * inset)
            let borderPath = NSBezierPath(roundedRect: insetBounds, xRadius: radius, yRadius: radius)
            borderPath.lineWidth = inset
            context.setStrokeColor(NSColor.lightGray.cgColor)
            context.setAlpha(0.7)
            borderPath.stroke()
        }
    }
}
