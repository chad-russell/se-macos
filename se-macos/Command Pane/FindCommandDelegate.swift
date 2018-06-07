//
//  FindCommandDelegate.swift
//  se-macos
//
//  Created by Chad Russell on 4/11/18.
//  Copyright © 2018 Chad Russell. All rights reserved.
//

import Cocoa

class FindCommandDelegate: CommandDelegate {
    
    var delegate: SECommandPaneViewController
        
    var title: String = "You can find things now"
    var stringData: String = ""
    
    let optionItems = [
        // find next
        TableViewItem(labelValue: NSAttributedString.init(string: "Find Next"), labelSubValue: NSAttributedString.init(string: ""), data: nil),
        
        // find previous
        TableViewItem(labelValue: NSAttributedString.init(string: "Find Previous"), labelSubValue: NSAttributedString.init(string: ""), data: nil),
        
        // find next and continue
        TableViewItem(labelValue: NSAttributedString.init(string: "Find Next and Keep Highlight"), labelSubValue: NSAttributedString.init(string: ""), data: nil),
        
        // find all
        TableViewItem(labelValue: NSAttributedString.init(string: "Find All"), labelSubValue: NSAttributedString.init(string: ""), data: nil),
    ]
    
    init(delegate: SECommandPaneViewController) {
        self.delegate = delegate
    }
    
    func refreshTableview(_ pattern: String) -> [TableViewItem] {
        stringData = pattern
        return optionItems
    }
    
    func select(_ selectedItemIndex: Int) {
        defer { self.delegate.bufferVC?.hideCommandView() }
        
        print("selected item: \(optionItems[selectedItemIndex].labelValue)")
        switch selectedItemIndex {
        case 0:
            // find
            delegate.bufferVC?.search(stringData)
        case 1:
            // find backward
            delegate.bufferVC?.searchBackward(stringData)
        case 2:
            // find forward and continue
            delegate.bufferVC?.searchForwardAndContinue(stringData)
        default: ()
        }
    }
    
}
