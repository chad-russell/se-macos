//
//  SearchCommandDelegate.swift
//  se-macos
//
//  Created by Chad Russell on 1/20/18.
//  Copyright © 2018 Chad Russell. All rights reserved.
//

import Cocoa

class SearchCommandDelegate: CommandDelegate {
    
    var delegate: SECommandPaneViewController
    
    let boldFont = NSFont.boldSystemFont(ofSize: 14)
    var filteredItems: [OutlineItem] = []
    var lastPatternLength: Int = 0
    
    var title: String = "File Search"
    
    init(delegate: SECommandPaneViewController) {
        self.delegate = delegate
        filteredItems = self.delegate.bufferVC!.flattenedFileOutlineItems.filter { !$0.isDirectory }
    }
    
    func refreshTableview(_ pattern: String) -> [TableViewItem] {
        if (pattern.count > 0) {
            let maxMatches = pattern.count
            let matches = UnsafeMutablePointer<UInt8>.allocate(capacity: maxMatches + 1)
            
            if pattern.count < lastPatternLength {
                filteredItems = self.delegate.bufferVC!.flattenedFileOutlineItems.filter { !$0.isDirectory }
            }
            
            lastPatternLength = pattern.count
            
            for item in filteredItems {
                let foundMatch = fuzzy_match(pattern, item.name.lastPathComponent, &(item.outScore), matches, Int32(maxMatches))

                if filteredItems.count < 1000 {
                    let realMatches = Array<UInt8>(UnsafeBufferPointer(start: matches, count: maxMatches))
                    // reset the attributes
                    item.attributedString.removeAttribute(.underlineStyle, range: NSRange(location: 0, length: item.name.lastPathComponent.count))
                    item.attributedString.setAttributes([:], range: NSRange(location: 0, length: item.name.lastPathComponent.count))
                    
                    if foundMatch == 1 {
                        for match in realMatches {
                            item.attributedString.addAttributes([.underlineStyle: NSUnderlineStyle.styleSingle.rawValue | NSUnderlineStyle.patternSolid.rawValue], range: NSRange(location: Int(match), length: 1))
                            
                            item.attributedString.addAttributes([NSAttributedStringKey.font: boldFont], range: NSRange(location: Int(match), length: 1))
                        }
                    }
                }
                
                item.foundMatch = foundMatch == 1
            }
            
            filteredItems = filteredItems
                .filter { $0.foundMatch }
                .sorted { $0.outScore > $1.outScore }
            
            free(matches)
            
            return filteredItems.map {
                let labelSubValue: NSAttributedString
                if let vc = delegate.bufferVC, let dir = vc.currentDirectory {
                    labelSubValue = NSAttributedString(string: String($0.name.path.dropFirst(dir.path.count + 1)))
                } else {
                    labelSubValue = NSAttributedString(string: "")
                }
                
                return TableViewItem(labelValue: $0.attributedString,
                              labelSubValue: labelSubValue,
                              data: $0)
            }
        } else {
//            for item in filteredItems {
//                item.attributedString.removeAttribute(.underlineStyle, range: NSRange(location: 0, length: item.name.lastPathComponent.count))
//            }
            
            return self.delegate.bufferVC!.flattenedFileOutlineItems
                .filter { !$0.isDirectory }
                .map {
                    let labelSubValue: NSAttributedString
                    if let vc = delegate.bufferVC, let dir = vc.currentDirectory {
                        labelSubValue = NSAttributedString(string: String($0.name.path.dropFirst(dir.path.count + 1)))
                    } else {
                        labelSubValue = NSAttributedString(string: "")
                    }
                    
                    return TableViewItem(labelValue: $0.attributedString,
                                         labelSubValue: labelSubValue,
                                         data: $0)
            }
        }
    }
    
    func select(_ selectedItemIndex: Int) {
        if let vc = delegate.bufferVC,
            delegate.tableViewItems.count > selectedItemIndex,
            let item = delegate.tableViewItems[selectedItemIndex].data as? OutlineItem {
            vc.openFile(withURL: item.name)
            vc.hideCommandView()
        }
    }
}
