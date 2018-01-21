//
//  SECommandPaneViewController.swift
//  se-macos
//
//  Created by Chad Russell on 8/28/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

struct TableViewItem {
    let labelValue: NSAttributedString
    let labelSubValue: NSAttributedString
    
    let data: Any?
}

protocol CommandDelegate {
    
    var delegate: SECommandPaneViewController { get set }
    var title: String { get }
    
    func refreshTableview(_ pattern: String) -> [TableViewItem]
    func select(_ selectedItemIndex: Int)
}

class SECommandPaneViewController: SEBufferViewControllerBase {
    
    @IBOutlet weak var paneHeight: NSLayoutConstraint!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!
    @IBOutlet weak var commandTitle: NSTextField!
    
    var bufferVC: SEBufferViewController?
    var selectedItemIndex: Int = 0
    var tableViewItems: [TableViewItem] = []
    var delegate: CommandDelegate? = nil
    
    override func reload() {
        guard let vc = bufferVC else { return }
        guard let buf = self.buf else { return }
        let stringBuf = editor_buffer_get_text_between_characters(buf, 0, editor_buffer_get_char_count(buf))
        defer { editor_buffer_free_buf(stringBuf) }
        guard let bufBytes = editor_buffer_get_buf_bytes(stringBuf) else { return }
        guard let delegate = delegate else { return }
        
        let pattern = String(cString: bufBytes)
        tableViewItems = delegate.refreshTableview(pattern)
        
        self.tableViewHeight.constant = (self.tableView.rowHeight + self.tableView.intercellSpacing.height)
            * CGFloat(self.numberOfRows(in: self.tableView))
        self.tableView.reloadData()
        
        self.bufferVC?.commandPaneHeight.constant = self.tableViewHeight.constant
        self.commandTitle.stringValue = delegate.title
        
        super.reload()
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
        self.editorView.layer?.cornerRadius = 2
        
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
            // enter
            delegate?.select(selectedItemIndex)
            selectedItemIndex = 0
            return
        } else if event.keyCode == 126 {
            // up
            selectedItemIndex = max(selectedItemIndex - 1, 0)
            self.tableView.scrollRowToVisible(selectedItemIndex)
            self.tableView.reloadData()
            return
        } else if event.keyCode == 125 {
            // down
            selectedItemIndex = min(selectedItemIndex + 1, tableViewItems.count - 1)
            self.tableView.scrollRowToVisible(selectedItemIndex)
            self.tableView.reloadData()
            return
        } else if event.keyCode == 123 {
            // left
            keyDownNoReload(with: event)
            return
        } else if event.keyCode == 124 {
            // right
            keyDownNoReload(with: event)
            return
        }
        
        super.handleKeyDown(with: event)
    }
    
    func keyDownNoReload(with event: NSEvent) {
        switch mode {
        case .insert: handleKeyDownForInsertMode(event)
        case .normal: handleKeyDownForNormalMode(event)
        case .visual: handleKeyDownForNormalMode(event)
        }
    }
}

extension SECommandPaneViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "commandResultView"), owner: self) as? SEFindTableCellView {
            cell.wantsLayer = true
            
            cell.fileNameLabel.attributedStringValue = tableViewItems[row].labelValue
            cell.row = row
            cell.delegate = self
            
            cell.relativePathLabel.attributedStringValue = tableViewItems[row].labelSubValue
            
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
        return Int(tableViewItems.count)
    }
}
