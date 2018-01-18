//
//  TreeViewDelegate.swift
//  se-macos
//
//  Created by Chad Russell on 1/15/18.
//  Copyright © 2018 Chad Russell. All rights reserved.
//

import Cocoa

class OutlineItem {
    let name: URL
    let children: [OutlineItem]
    var expanded: Bool = false
    
    init(name: URL, children: [OutlineItem]) {
        self.name = name
        self.children = children
    }
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
        var view: SETreeViewCell?
        
        if let item = item as? OutlineItem {
            view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "OutlineItemCell"), owner: self) as? SETreeViewCell
            
            if let textField = view?.label {
                textField.stringValue = item.name.lastPathComponent
                textField.sizeToFit()
            }
            
            if let image = view?.image {
                if item.children.isEmpty {
                    image.image = NSImage(named: NSImage.Name("file-plain"))
                } else {
                    if item.expanded {
                        image.image = NSImage(named: NSImage.Name("folder-open"))
                    } else {
                        image.image = NSImage(named: NSImage.Name("folder-closed"))
                    }
                }
            }
        }
        
        return view
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return true
    }
    
    func outlineViewItemWillExpand(_ notification: Notification) {
        if let item = notification.userInfo!["NSObject"] as? OutlineItem {
            item.expanded = true
            self.outlineView.reloadItem(item)
        }
    }

    func outlineViewItemWillCollapse(_ notification: Notification) {
        if let item = notification.userInfo!["NSObject"] as? OutlineItem {
            item.expanded = false
            self.outlineView.reloadItem(item)
        }
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
