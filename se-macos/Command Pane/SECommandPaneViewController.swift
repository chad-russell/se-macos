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
    
    override func reload() {
        let height = preferences.charHeight() + 12
        if paneHeight.constant != height {
            paneHeight.constant = height
        }
        
        self.tableView.reloadData()
        tableViewHeight.constant = (self.tableView.rowHeight + self.tableView.intercellSpacing.height) * CGFloat(numberOfRows(in: self.tableView))
        
        super.reload()
    }
    
    override func viewDidLoad() {
        self.editorView.layer?.cornerRadius = 5
        super.viewDidLoad()
    }
    
    override func handleKeyDown(with event: NSEvent) {
        if event.keyCode == 35 && event.modifierFlags.contains(.command) {
            // cmd + p
            bufferVC?.toggleCommandView()
            return
        }
        
        switch mode {
        case .insert: handleKeyDownForInsertMode(event)
        case .normal: handleKeyDownForNormalMode(event)
        }
        
        reload()
    }
}

extension SECommandPaneViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "commandResultView"), owner: self) {
            return cell
        }
        return nil
    }
}

extension SECommandPaneViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let buf = buf else { return 0 }
        return Int(editor_buffer_get_char_count(buf))
    }
}
