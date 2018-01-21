//
//  SEFindTableCellView.swift
//  se-macos
//
//  Created by Chad Russell on 1/17/18.
//  Copyright © 2018 Chad Russell. All rights reserved.
//

import Cocoa

class SEFindTableCellView: NSTableCellView {
    
    @IBOutlet weak var fileNameLabel: NSTextField!
    @IBOutlet weak var relativePathLabel: NSTextField!
    
    var row: Int = -1
    var delegate: SECommandPaneViewController?
    
    override func mouseDown(with event: NSEvent) {
        self.layer?.backgroundColor = CGColor(red: CGFloat(187) / 255, green: CGFloat(191) / 255, blue: CGFloat(199) / 255, alpha: 1)
    }
    
    override func mouseUp(with event: NSEvent) {
        delegate?.selectedItemIndex = row
        delegate?.delegate?.select(row)
    }
    
}
