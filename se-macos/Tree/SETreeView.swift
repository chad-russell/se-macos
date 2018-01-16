//
//  SETreeView.swift
//  se-macos
//
//  Created by Chad Russell on 1/14/18.
//  Copyright © 2018 Chad Russell. All rights reserved.
//

import Cocoa

class SETreeView: NSView {
    // todo(chad): change this to an interface type
    var delegate: SEBufferViewController?
    
    var resizer: SETreeViewResizer?
    
    var mouseDownX: CGFloat = 0
    var mouseDownWidth: CGFloat = 0
}
