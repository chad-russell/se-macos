
//
//  SETextTableViewController.swift
//  se-macos
//
//  Created by Chad Russell on 7/23/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SETextTableViewController : NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var tableView: SETableView!
    @IBOutlet weak var undoSlider: NSSlider!
    @IBOutlet weak var globalUndoSlider: NSSlider!
    
    var buf: editor_buffer_t?
    var screen: editor_screen_t?
    
    var oldUndoSliderValue: Double = 0
    var oldGlobalUndoSliderValue: Double = 0
    
    let virtualNewlines = true
    let virtualNewlineLength = Int64(10)
    
    func reload() {
        self.tableView.reloadData()
        
        let undoSize = editor_buffer_get_undo_size(buf!)
        self.undoSlider.maxValue = Double(undoSize - 1)
        self.undoSlider.numberOfTickMarks = Int(undoSize - 1)
        self.undoSlider.intValue = Int32(editor_buffer_get_undo_index(buf!))
        
        let globalUndoSize = editor_buffer_get_global_undo_size(buf!)
        self.globalUndoSlider.maxValue = Double(globalUndoSize - 1)
        self.globalUndoSlider.numberOfTickMarks = Int(globalUndoSize - 1)
        self.globalUndoSlider.intValue = Int32(editor_buffer_get_global_undo_index(buf!))
    }
    
    func seSave(sender: NSMenuItem) {
        editor_buffer_save_file(buf!)
    }
    
    func seOpen(sender: NSMenuItem) {
        let dialog = NSOpenPanel();
        
        dialog.title = "Choose a file"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["txt", "json", "java", "xml", "html"]
        
        if dialog.runModal() == NSModalResponseOK {
            let result = dialog.url // Pathname of the file
            
            if result != nil {
                let path = result!.path
                
                screen = editor_buffer_open_file(buf!, path)
                reload()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.controller = self
        
        buf = editor_buffer_create()
        screen = editor_buffer_get_current_screen(buf!)
        
        undoSlider.doubleValue = 0;
        globalUndoSlider.doubleValue = 0;
        
//        let selectionFrame: NSRect = NSMakeRect(32, 32, 200, 200)
//        let selectionView = NSView(frame: selectionFrame)
//        selectionView.wantsLayer = true
//        selectionView.layer?.backgroundColor = NSColor.green.cgColor
//        selectionView.layer?.opacity = 0.5
//        self.tableView.addSubview(selectionView)
        
        reload()
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if buf == nil {
            return 0
        }
        
        let lineCount: Int64
        if virtualNewlines {
            lineCount = editor_buffer_get_virtual_line_count(buf!, virtualNewlineLength)
        } else {
            lineCount = editor_screen_get_line_count(screen!)
        }
        
        return Int(lineCount)
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if buf == nil {
            return nil
        }
        
        let cell = self.tableView.make(withIdentifier: "Cell", owner: self) as! SETableCellView
        cell.controller = self
        cell.row = row
        cell.reload()
        
        return cell
    }
    
    override var acceptsFirstResponder: Bool { return true }
    
    override func keyDown(with event: NSEvent) {
        if let chars = event.characters {
            if event.keyCode == 51 {
                // backspace
                screen = editor_buffer_delete(buf!)
                reload()
            } else if event.keyCode == 123 {
                // left
                screen = editor_buffer_set_cursor_pos_relative(buf!, -1)
                reload()
            } else if event.keyCode == 124 {
                // right
                screen = editor_buffer_set_cursor_pos_relative(buf!, 1)
                reload()
            } else if event.keyCode == 125 {
                // down
                
                let cursorRow: Int64
                let cursorCol: Int64
                if virtualNewlines {
                    cursorRow = editor_screen_get_cursor_row_virtual(screen!, virtualNewlineLength)
                    cursorCol = editor_screen_get_cursor_col_virtual(screen!, virtualNewlineLength)
                    
                    screen = editor_buffer_set_cursor_point_virtual(buf!, cursorRow + 1, cursorCol, virtualNewlineLength)
                } else {
                    cursorRow = editor_screen_get_cursor_row(screen!)
                    cursorCol = editor_screen_get_cursor_col(screen!)
                    screen = editor_buffer_set_cursor_point(buf!, cursorRow + 1, cursorCol)
                }
                
                reload()
            } else if event.keyCode == 126 {
                // up
                
                let cursorRow: Int64
                let cursorCol: Int64
                if virtualNewlines {
                    cursorRow = editor_screen_get_cursor_row_virtual(screen!, virtualNewlineLength)
                    cursorCol = editor_screen_get_cursor_col_virtual(screen!, virtualNewlineLength)
                    screen = editor_buffer_set_cursor_point_virtual(buf!, cursorRow - 1, cursorCol, virtualNewlineLength)
                } else {
                    cursorRow = editor_screen_get_cursor_row(screen!)
                    cursorCol = editor_screen_get_cursor_col(screen!)
                    screen = editor_buffer_set_cursor_point(buf!, cursorRow - 1, cursorCol)
                }
                
                reload()
            } else if event.keyCode == 36 {
                // enter
                screen = editor_buffer_insert(buf!, "\n")
                reload()
            } else {
                // append chars
                screen = editor_buffer_insert(buf!, chars)
                reload()
            }
        }
    }
    
    @IBAction func undoValueChanged(_ sender: NSSlider) {
        if oldUndoSliderValue != sender.doubleValue {
            screen = editor_buffer_undo(buf!, Int64(sender.intValue))
            reload()
            
            globalUndoSlider.doubleValue = globalUndoSlider.maxValue
            oldUndoSliderValue = sender.doubleValue
        }
    }
    
    @IBAction func globalUndoValueChanged(_ sender: NSSlider) {
        if oldGlobalUndoSliderValue != sender.doubleValue {
            screen = editor_buffer_global_undo(buf!, Int64(globalUndoSlider.intValue))
            reload()
            
            undoSlider.doubleValue = undoSlider.maxValue
            oldGlobalUndoSliderValue = sender.doubleValue
        }
    }
    ;
}
