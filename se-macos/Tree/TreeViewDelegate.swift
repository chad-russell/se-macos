//
//  TreeViewDelegate.swift
//  se-macos
//
//  Created by Chad Russell on 1/15/18.
//  Copyright © 2018 Chad Russell. All rights reserved.
//

import Cocoa

enum OutlineItemSelection {
    case tentative
    case selected
    case none
}

extension OutlineItemSelection {
    func getColor() -> NSColor {
        switch self {
        case .tentative:
            return NSColor(red: 230.0 / 255, green: 233.0 / 255, blue: 237.0 / 255, alpha: 1)
        case .selected:
            return NSColor(red: 207.0 / 255, green: 211.0 / 255, blue: 219.0 / 255, alpha: 1)
        case .none:
            return NSColor.clear
        }
    }
}

class OutlineItem {
    let name: URL
    var expanded: Bool = false
    let index: Int
    var childCount = 0
    let isDirectory: Bool
    var attributedString: NSMutableAttributedString
    
    // for 'mapping'
    var foundMatch = false
    var outScore: Int32 = 0
    
    init(name: URL, index: Int, isDirectory: Bool) {
        self.name = name
        self.index = index
        self.attributedString = NSMutableAttributedString(string: name.lastPathComponent)
        self.isDirectory = isDirectory
    }
}

extension OutlineItem: CustomDebugStringConvertible {
    var debugDescription: String {
        return "name: '\(name.lastPathComponent)', childCount: \(childCount)"
    }
}

extension SEBufferViewController: NSOutlineViewDelegate, NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let item = item as? OutlineItem {
            return item.childCount
        }
        
        if !flattenedFileOutlineItems.isEmpty {
            return 1
        }
        
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item = item as? OutlineItem {
            var childrenToGo = index + 1
            var totalSkipAhead = 1
            
            while childrenToGo > 0 {
                childrenToGo -= 1
                
                if childrenToGo == 0 {
                    return flattenedFileOutlineItems[item.index + totalSkipAhead]
                }
                
                childrenToGo += flattenedFileOutlineItems[item.index + totalSkipAhead].childCount
                totalSkipAhead += 1
            }
            
            assert(false)
        }
        
        if !flattenedFileOutlineItems.isEmpty {
            return flattenedFileOutlineItems[0]
        }
        
        assert(false)
        return ()
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let item = item as? OutlineItem {
            return item.isDirectory
        }
    
        assert(false)
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        var view: SETreeViewCell?
        
        if let item = item as? OutlineItem {
            view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "OutlineItemCell"), owner: self) as? SETreeViewCell
            view?.wantsLayer = true
            
            if let textField = view?.label {
                textField.stringValue = item.name.lastPathComponent
                textField.sizeToFit()
            }
            
            if let image = view?.image {
                if !item.isDirectory {
                    image.image = NSImage(named: NSImage.Name("file-plain"))
                } else {
                    if item.expanded {
                        image.image = NSImage(named: NSImage.Name("folder-open"))
                    } else {
                        image.image = NSImage(named: NSImage.Name("folder-closed"))
                    }
                }
            }
            
//            view?.layer?.backgroundColor = item.index == outlineView.selectedRow ?
//                OutlineItemSelection.selected.getColor().cgColor :
//                OutlineItemSelection.none.getColor().cgColor
            
//            view?.outlineItem = item
//            view?.delegate = self
        }
        
        return view
    }
    
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return SEOutlineRowView()
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
            if item.isDirectory {
                if item.expanded {
                    self.outlineView.collapseItem(item)
                } else {
                    self.outlineView.expandItem(item)
                }
                
                self.outlineView.deselectAll(nil)
            } else {
                self.selectedOutlineIndex = item.index
                
                editor_buffer_destroy(self.buf!)
                self.buf = editor_buffer_create(UInt32(preferences.virtualNewlineLength))
                
                editor_buffer_open_file(self.buf!, UInt32(self.preferences.virtualNewlineLength), item.name.path)
                
                self.reload()
            }
        }
    }
}
