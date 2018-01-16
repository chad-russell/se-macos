//
//  TreeViewDelegate.swift
//  se-macos
//
//  Created by Chad Russell on 1/15/18.
//  Copyright © 2018 Chad Russell. All rights reserved.
//

import Cocoa

struct OutlineItem {
    let name: URL
    let children: [OutlineItem]
}

extension SEBufferViewController: NSOutlineViewDelegate, NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let item = item as? OutlineItem {
            return item.children.count
        }
        
        return outlineItems.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item = item as? OutlineItem {
            return item.children[index]
        }
        
        return outlineItems[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let item = item as? OutlineItem {
            return !item.children.isEmpty
        }
        
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        var view: NSTableCellView?
        if let item = item as? OutlineItem {
            view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "OutlineItemCell"), owner: self) as? NSTableCellView
            if let textField = view?.textField {
                textField.stringValue = item.name.lastPathComponent
                textField.sizeToFit()
            }
        }
        return view
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return true
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        if let item = self.outlineView.item(atRow: self.outlineView.selectedRow) as? OutlineItem {
            if item.children.isEmpty {
                editor_buffer_destroy(self.buf!)
                self.buf = editor_buffer_create(UInt32(preferences.virtualNewlineLength))
                
                editor_buffer_open_file(self.buf!, UInt32(self.preferences.virtualNewlineLength), item.name.path)
                self.reload()
            }
        }
        
    }
}
