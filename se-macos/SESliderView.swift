//
//  SESliderView.swift
//  se-macos
//
//  Created by Chad Russell on 8/9/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SESliderView : NSView {
    
    var max: Int = 1 {
        didSet {
            self.setNeedsDisplay(self.bounds)
        }
    }
    
    var savedValue: Int = 0
    var value: Int = 0 {
        didSet {
            savedValue = value
            self.setNeedsDisplay(self.bounds)
        }
    }
    
    var shouldDrag = false
    
    var delegate: SESliderViewDelegate? = nil
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let context = NSGraphicsContext.current?.cgContext
        context?.setFillColor(red: 1.0, green: 0, blue: 0.4, alpha: 1)
        context?.setStrokeColor(CGColor.black)
        
        context?.fill(rect())
    }
    
    func rect() -> CGRect {
        let width = self.bounds.width / 100
        
        let margin: CGFloat = 5
        var x: CGFloat = margin
        if self.max != 1 {
            x = margin + CGFloat(self.value) / CGFloat(self.max - 1) * (self.bounds.width - (width + 2 * margin))
        }
        
        return CGRect(x: x,
               y: self.bounds.origin.y,
               width: width,
               height: self.bounds.height)
    }
    
    override func mouseDown(with event: NSEvent) {
        let localLocation = self.convert(event.locationInWindow, from: nil)
        if rect().contains(localLocation) {
            shouldDrag = true
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        if !shouldDrag { return }
        
        let localLocation = self.convert(event.locationInWindow, from: nil)
        
        var computedValue = Int(localLocation.x / self.bounds.width * CGFloat(max))
        if computedValue > max - 1 { computedValue = max - 1 }
        if computedValue < 0 { computedValue = 0 }
        
        if computedValue != savedValue {
            savedValue = computedValue
            delegate?.valueChanged(self)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        shouldDrag = false
    }
}

protocol SESliderViewDelegate {
    
    func valueChanged(_ sliderView: SESliderView)
    
}
