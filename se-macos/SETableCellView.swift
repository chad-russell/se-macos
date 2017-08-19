//
//  SETableCellView.swift
//  se-macos
//
//  Created by Chad Russell on 7/25/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SETableCellView : NSTableCellView {
    
    @IBOutlet weak var row0: SELineView!
    @IBOutlet weak var row1: SELineView!
    @IBOutlet weak var row2: SELineView!
    @IBOutlet weak var row3: SELineView!
    @IBOutlet weak var row4: SELineView!
    @IBOutlet weak var row5: SELineView!
    @IBOutlet weak var row6: SELineView!
    @IBOutlet weak var row7: SELineView!
    
    var controller: SETextTableViewController? {
        didSet {
            row0.controller = controller
            row1.controller = controller
            row2.controller = controller
            row3.controller = controller
            row4.controller = controller
            row5.controller = controller
            row6.controller = controller
            row7.controller = controller
        }
    }
    
    var row: Int? {
        didSet {
            row0.row = row! * 8
            row1.row = row! * 8 + 1
            row2.row = row! * 8 + 2
            row3.row = row! * 8 + 3
            row4.row = row! * 8 + 4
            row5.row = row! * 8 + 5
            row6.row = row! * 8 + 6
            row7.row = row! * 8 + 7
        }
    }
    
    func reload() {
        row0.reload()
        row1.reload()
        row2.reload()
        row3.reload()
        row4.reload()
        row4.reload()
        row5.reload()
        row6.reload()
        row7.reload()
    }
    
    override func mouseDragged(with event: NSEvent) {
        self.nextResponder?.mouseDragged(with: event)
    }
    
}
