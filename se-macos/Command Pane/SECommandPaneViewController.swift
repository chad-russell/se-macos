//
//  SECommandPaneViewController.swift
//  se-macos
//
//  Created by Chad Russell on 8/28/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SECommandPaneViewController: SEBufferViewControllerBase {
    
    @IBOutlet weak var paneHeight: NSLayoutConstraint!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!
    
    var bufferVC: SEBufferViewController?
    
    var filteredItems: [(OutlineItem, NSMutableAttributedString?)] = []
    var selectedItemIndex: Int = 0
    
    override func reload() {
        guard let vc = bufferVC else { return }
        guard let buf = self.buf else { return }
        let stringBuf = editor_buffer_get_text_between_characters(buf, 0, editor_buffer_get_char_count(buf))
        defer { editor_buffer_free_buf(stringBuf) }
        guard let bufBytes = editor_buffer_get_buf_bytes(stringBuf) else { return }
        let swiftString = String(cString: bufBytes)
        
        filteredItems = vc.flattenedFileOutlineItems.map {
            ($0, fuzzy_match(pattern: swiftString, str: $0.name.lastPathComponent))
            }.filter { $0.1 != nil }
        
        self.tableView.reloadData()
        tableViewHeight.constant = (self.tableView.rowHeight + self.tableView.intercellSpacing.height) * CGFloat(numberOfRows(in: self.tableView))

        super.reload()
    }
    
    func fuzzy_match(pattern: String, str: String) -> NSMutableAttributedString? {
        // Score consts
        let adjacency_bonus = 5                // bonus for adjacent matches
        let separator_bonus = 10               // bonus if match occurs after a separator
        let camel_bonus = 10                   // bonus if match is uppercase and prev is lower
        let leading_letter_penalty = -3        // penalty applied for every letter in str before the first match
        let max_leading_letter_penalty = -9    // maximum penalty for leading letters
        let unmatched_letter_penalty = -1      // penalty for every letter that doesn't matter

        // Loop variables
        var score = 0
        var patternIdx = 0
        let patternLength = pattern.count
        var strIdx = 0
        let strLength = str.count
        var prevMatched = false
        var prevLower = false
        var prevSeparator = true       // true so if first letter match gets separator bonus

        // Use "best" matched letter if multiple string letters match the pattern
        var bestLetter: String?
        var bestLower: String?
        var bestLetterIdx: Int?
        var bestLetterScore = 0

        var matchedIndices: [Int] = []

        var strStr = String.SubSequence(str)
        
        // Loop over strings
        while (strIdx != strLength) {
            let patternChar = patternIdx != patternLength
                ? String(pattern[pattern.index(pattern.startIndex, offsetBy: patternIdx)])
                : nil
            
            let strChar = String(strStr.first!)

            let patternLower = patternChar?.lowercased()

            let strLower = strChar.lowercased()
            let strUpper = strChar.uppercased()

            let nextMatch = patternChar != nil && patternLower == strLower
            let rematch = bestLetter != nil && bestLower == strLower

            let advanced = bestLetter != nil
            let patternRepeat = bestLetter != nil && patternChar != nil && bestLower == patternLower
            if (advanced || patternRepeat) {
                score += bestLetterScore
                
                if let bli = bestLetterIdx {
                    matchedIndices.append(bli)
                }
                
                bestLetter = nil
                bestLower = nil
                bestLetterIdx = nil
                bestLetterScore = 0
            }

            if (nextMatch || rematch) {
                var newScore = 0

                // Apply penalty for each letter before the first pattern match
                // Note: std::max because penalties are negative values. So max is smallest penalty.
                if (patternIdx == 0) {
                    let penalty = max(strIdx * leading_letter_penalty, max_leading_letter_penalty)
                    score += penalty
                }

                // Apply bonus for consecutive bonuses
                if (prevMatched) {
                    newScore += adjacency_bonus
                }

                // Apply bonus for matches after a separator
                if (prevSeparator) {
                    newScore += separator_bonus
                }


                // Apply bonus across camel case boundaries. Includes "clever" isLetter check.
                if (prevLower && strChar == strUpper && strLower != strUpper) {
                    newScore += camel_bonus
                }

                // Update patter index IFF the next pattern letter was matched
                if (nextMatch) {
                    patternIdx += 1
                }
            
                // Update best letter in str which may be for a "next" letter or a "rematch"
                if (newScore >= bestLetterScore) {

                    // Apply penalty for now skipped letter
                    if (bestLetter != nil) {
                        score += unmatched_letter_penalty
                    }
                
                    bestLetter = strChar
                    bestLower = bestLetter?.lowercased()
                    bestLetterIdx = strIdx
                    bestLetterScore = newScore
                }
            
                prevMatched = true
            }
            else {
                score += unmatched_letter_penalty
                prevMatched = false
            }

            // Includes "clever" isLetter check.
            prevLower = strChar == strLower && strLower != strUpper
            prevSeparator = strChar == "_" || strChar == " "

            strIdx += 1
            strStr = strStr.dropFirst()
        }

        // Apply score for last match
        if (bestLetter != nil) {
            score += bestLetterScore
            
            if let bli = bestLetterIdx {
                matchedIndices.append(bli)
            }
        }

        let formattedStr = NSMutableAttributedString(string: str)
        for index in matchedIndices {
            let attrs: [NSAttributedStringKey: Any] = [
                .underlineStyle: NSUnderlineStyle.patternSolid.rawValue | NSUnderlineStyle.styleSingle.rawValue,
                .font: NSFont.boldSystemFont(ofSize: 14)
            ]
            
            formattedStr.addAttributes(attrs, range: NSRange(location: index, length: 1))
        }

        let matched = patternIdx == patternLength
        
        return matched ? formattedStr : nil
    }
    
    override func loadConfigFile() {
        super.loadConfigFile()
        recalculatePaneHeight()
    }
    
    override func increaseFontSize() {
        super.increaseFontSize()
        recalculatePaneHeight()
        
    }
    
    override func decreaseFontSize() {
        super.decreaseFontSize()
        recalculatePaneHeight()
    }
    
    func recalculatePaneHeight() {
        let height = preferences.charHeight + 10
        if paneHeight.constant != height {
            paneHeight.constant = height
        }
    }
    
    override func viewDidLoad() {
//        self.editorView.layer?.cornerRadius = 5
        
        reload()
        
        self.tableView.backgroundColor = NSColor(red: CGFloat(230) / 255, green: CGFloat(232) / 255, blue: CGFloat(235) / 255, alpha: 1)
        
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = self.tableView.backgroundColor.cgColor
        
        bufferVC?.commandViewController = self
        
        super.viewDidLoad()
    }
    
    override func handleKeyDown(with event: NSEvent) {
        if event.keyCode == 35 && event.modifierFlags.contains(.command) {
            // cmd + p
            bufferVC?.hideCommandView()
            return
        } else if event.keyCode == 36 {
            // enter (do nothing since this should just be a single line always)
            bufferVC?.openFile(withURL: filteredItems[selectedItemIndex].0.name)
            bufferVC?.toggleCommandView()
            return
        } else if event.keyCode == 126 {
            // up
            selectedItemIndex = max(selectedItemIndex - 1, 0)
            self.tableView.scrollRowToVisible(selectedItemIndex)
        } else if event.keyCode == 125 {
            // down
            selectedItemIndex = min(selectedItemIndex + 1, filteredItems.count - 1)
            self.tableView.scrollRowToVisible(selectedItemIndex)
        } else {
            switch mode {
            case .insert: handleKeyDownForInsertMode(event)
            case .normal: handleKeyDownForNormalMode(event)
            case .visual: handleKeyDownForNormalMode(event)
            }
        }
        
        reload()
    }
}

extension SECommandPaneViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "commandResultView"), owner: self) as? SEFindTableCellView {
            cell.wantsLayer = true
            
            if let attr = filteredItems[row].1 {
                cell.fileNameLabel.attributedStringValue = attr
            } else {
                cell.fileNameLabel.stringValue = filteredItems[row].0.name.lastPathComponent
            }
            
            if let vc = bufferVC, let dir = vc.currentDirectory {
                cell.relativePathLabel.stringValue = String(filteredItems[row].0.name.path.dropFirst(dir.path.count + 1))
            } else {
                cell.relativePathLabel.stringValue = ""
            }
            
            if selectedItemIndex == row {
                cell.layer?.backgroundColor = CGColor(red: CGFloat(187) / 255, green: CGFloat(191) / 255, blue: CGFloat(199) / 255, alpha: 1)
            } else {
                cell.layer?.backgroundColor = self.tableView.backgroundColor.cgColor
            }
            return cell
        }
        return nil
    }
}

extension SECommandPaneViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return Int(filteredItems.count)
    }
}
