//
//  SETableView.swift
//  se-macos
//
//  Created by Chad Russell on 7/25/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SETableView : NSTableView {

    var controller: SETextTableViewController!
    
    override func keyDown(with event: NSEvent) {
        self.nextResponder?.keyDown(with: event)
    }
    
//    override func mouseDown(with event: NSEvent) {
//        let localLocation = self.convert(event.locationInWindow, from: nil)
//        let clickedRow = self.row(at: localLocation)
//        
//        editor_buffer_set_cursor_is_selection(controller!.buf!, event.modifierFlags.contains(.shift) ? 1 : 0)
//        
//        if clickedRow != -1 {
//            let eventInTableView = self.convert(event.locationInWindow, from: nil)
//            let rowOrigin = self.rect(ofRow: clickedRow).origin
//            let localToRow = CGPoint(x: eventInTableView.x - rowOrigin.x, y: eventInTableView.y - rowOrigin.y)
//            
//            let rowView = self.view(atColumn: 0, row: clickedRow, makeIfNecessary: false)! as! SETableCellView
//            
//            let clickedCol = rowView.colForCharAt(point: localToRow)
//            
//            if controller!.virtualNewlines {
//                editor_buffer_set_cursor_point_virtual(controller!.buf!, Int64(clickedRow), Int64(clickedCol), controller!.virtualNewlineLength)
//            } else {
//                editor_buffer_set_cursor_point(controller!.buf!, Int64(clickedRow), Int64(clickedCol))
//            }
//            
//            controller!.reload()
//        }
//    }
    
    override func mouseDragged(with event: NSEvent) {
        Swift.print("mouse dragged!")
    }

}
