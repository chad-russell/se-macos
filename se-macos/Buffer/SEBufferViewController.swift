
//
//  SEEditorViewController.swift
//  se-macos
//
//  Created by Chad Russell on 8/21/17.
//  Copyright © 2017 Chad Russell. All rights reserved.
//

import Cocoa

class SEBufferViewController: SEBufferViewControllerBase {
    
    @IBOutlet weak var gutterView: SEGutterView!
    @IBOutlet weak var undoSlider: SESliderView!
    @IBOutlet weak var globalUndoSlider: SESliderView!
    
    @IBOutlet weak var gutterViewWidth: NSLayoutConstraint!
    @IBOutlet weak var editorViewWidth: NSLayoutConstraint!
    @IBOutlet weak var editorViewHeight: NSLayoutConstraint!
    
    @IBOutlet weak var footerView: NSView!
    @IBOutlet weak var modeLabel: NSTextField!
    @IBOutlet weak var positionLabel: NSTextField!
    @IBOutlet weak var fileExtensionLabel: NSTextField!
    
    @IBOutlet weak var treeView: SETreeView!
    
    @IBOutlet weak var treeViewWidth: NSLayoutConstraint!
    var lastTreeViewWidth: CGFloat = 200
    
    @IBOutlet weak var treeViewMinWidth: NSLayoutConstraint!
    @IBOutlet weak var treeViewResizer: SETreeViewResizer!
    @IBOutlet weak var treeViewResizerWidth: NSLayoutConstraint!
    @IBOutlet weak var outlineView: NSOutlineView!
    
    @IBOutlet weak var openFilesWidth: NSLayoutConstraint!
    @IBOutlet weak var commandView: NSView!
    
    @IBOutlet weak var commandPaneHeight: NSLayoutConstraint!
    
    override var lineWidthConstraint: NSLayoutConstraint? { return editorViewWidth }
    
    var commandViewController: SECommandPaneViewController?
    
    var showingCommandView = true
    var lastMouseDownInsideView = false
    
    var currentDirectory: URL?
    var flattenedFileOutlineItems: [OutlineItem] = []
    var selectedOutlineIndex: Int = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.gutterView.delegate = self
        
        undoSlider.max = 0;
        undoSlider.value = 0;
        undoSlider.delegate = self;
        
        globalUndoSlider.max = 0;
        globalUndoSlider.value = 0;
        globalUndoSlider.delegate = self;
        
        gutterView.enclosingScrollView?.horizontalScroller?.alphaValue = 0
        gutterView.enclosingScrollView?.verticalScroller?.alphaValue = 0
        
        self.fileExtensionLabel.stringValue = "No File Extension"
        
        self.treeView.isHidden = true
        self.treeViewResizer.isHidden = true
        
        self.treeView.wantsLayer = true
        self.treeView.layer?.backgroundColor = NSColor.white.cgColor
        self.treeView.delegate = self
        self.treeView.resizer = treeViewResizer
        self.treeViewResizer.delegate = self.treeView
        
        self.treeViewResizer.wantsLayer = true
        self.treeViewResizer.layer?.backgroundColor = NSColor.white.cgColor
        
        self.treeViewWidth.constant = 0
        self.treeViewResizerWidth.constant = 0
        self.openFilesWidth.constant = 0
        
        let synchronizedContentView = editorView.enclosingScrollView!.contentView
        synchronizedContentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(synchronizedViewContentBoundsDidChange), name: NSView.boundsDidChangeNotification, object: synchronizedContentView)
        
        hideCommandView()
    }
    
    func refreshOutlineItems(_ url: URL) {
        populateOutlineItems(url: url)
        self.outlineView.reloadData()
    }
    
    override func viewWillDisappear() {
        NotificationCenter.default.removeObserver(self)
        editor_buffer_destroy(buf!)
    }
    
    func populateOutlineItems(url: URL) {
        let contents = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: FileManager.DirectoryEnumerationOptions.skipsHiddenFiles, errorHandler: nil)!
        
        flattenedFileOutlineItems = []
        
        let outlineItem = OutlineItem(name: url, index: flattenedFileOutlineItems.count, isDirectory: url.isDirectory)
        let parentIndexStack: NSMutableArray = [contents.level]
        var currentParent = outlineItem
        
        flattenedFileOutlineItems.append(outlineItem)
        
        for case let child as URL in contents {
            let isDirectory = child.isDirectory
            
            let excludePatterns = isDirectory ? preferences.folderExcludePatterns : preferences.fileExcludePatterns
            
            if contents.level == parentIndexStack.count + 1 {
                parentIndexStack.add(flattenedFileOutlineItems.count - 1)
            } else {
                assert(contents.level <= parentIndexStack.count)
                
                while contents.level < parentIndexStack.count {
                    parentIndexStack.removeLastObject()
                }
            }
            
            currentParent = flattenedFileOutlineItems[parentIndexStack.lastObject as! Int]
            
            var exclude = false
            for pattern in excludePatterns {
                if child.path.contains(pattern) {
                    exclude = true
                }
            }
            
            if !exclude {
                currentParent.childCount += 1
                flattenedFileOutlineItems.append(OutlineItem(name: child, index: flattenedFileOutlineItems.count, isDirectory: isDirectory))
            } else if isDirectory {
                contents.skipDescendants()
            }
        }
    }
    
    @objc
    func synchronizedViewContentBoundsDidChange(_ notification: NSNotification) {
        let changedContentView = notification.object as! NSClipView
        let changedBoundsOrigin = changedContentView.documentVisibleRect.origin
        let curOffset = editorView.enclosingScrollView!.bounds.origin
        var newOffset = curOffset
        newOffset.y = changedBoundsOrigin.y
        
//        if !NSEqualPoints(curOffset, newOffset) {
            gutterView.enclosingScrollView!.scroll(gutterView.enclosingScrollView!.contentView, to: newOffset)
//        }
    }
    
    override func handleMouseDown(with theEvent: NSEvent) {
        self.lastMouseDownInsideView = true
        
        if showingCommandView {
            self.commandViewController?.handleMouseDown(with: theEvent)
            return
        }
        
        self.updateFooterView()
        
        super.handleMouseDown(with: theEvent)
    }
    
    override func handleMouseDragged(with event: NSEvent) {
        if !self.lastMouseDownInsideView { return }
        
        if showingCommandView {
            self.commandViewController?.handleMouseDragged(with: event)
            return
        }
        
        super.handleMouseDragged(with: event)
    }
    
    override func handleMouseUp(with theEvent: NSEvent) {
        self.lastMouseDownInsideView = false
        
        if showingCommandView {
            self.commandViewController?.handleMouseUp(with: theEvent)
            return
        }
    }
    
    func hideCommandView() {
        if !showingCommandView { return }
        
        showingCommandView = false
        self.commandView.isHidden = true
        self.editorView.showCursor = true
        self.editorView.needsDisplay = true
    }
    
    func showCommandView(delegate: CommandDelegate) {
        if showingCommandView { return }
        
        showingCommandView = true
        
        if let cvc = self.commandViewController {
            cvc.delegate = delegate
        }
        
        // clear all text
        // @TODO(chad): clean this up a LOT
        if let vcBuf = self.commandViewController?.buf {
            editor_buffer_set_cursor_pos(vcBuf, 0)
            let chars = editor_buffer_get_char_count(vcBuf)
            editor_buffer_set_cursor_is_selection(vcBuf, 1)
            editor_buffer_set_cursor_pos(vcBuf, chars)
            editor_buffer_delete(vcBuf)
            editor_buffer_set_cursor_is_selection(vcBuf, 0)
        }
        
        self.commandViewController?.reload()
        self.commandView.isHidden = false
        self.editorView.showCursor = false
        self.editorView.needsDisplay = true
    }
    
    func toggleCommandView(delegate: CommandDelegate) {
        if showingCommandView { hideCommandView() }
        else { showCommandView(delegate: delegate) }
    }
    
    override func handleKeyDown(with event: NSEvent) {
        if event.keyCode == 35 && event.modifierFlags.contains(.command) {
            // cmd + p
            if let cvc = self.commandViewController {
                toggleCommandView(delegate: SearchCommandDelegate(delegate: cvc))
            }
            return
        } else if event.keyCode == 40 && event.modifierFlags.contains(.command) {
            // cmd + k
            toggleTreeView()
            return
        } else if event.keyCode == 37 && event.modifierFlags.contains(.command) {
            // cmd + l
            if let cvc = self.commandViewController {
                toggleCommandView(delegate: JumpToLocationCommandDelegate(delegate: cvc))
            }
            return
        } else if event.keyCode == 3 && event.modifierFlags.contains(.command) {
            // cmd + f
            if let cvc = self.commandViewController {
                toggleCommandView(delegate: FindCommandDelegate(delegate: cvc))
            }
        }
        
        if showingCommandView {
            self.commandViewController?.handleKeyDown(with: event)
            return
        }
        
        super.handleKeyDown(with: event)
    }
    
    func toggleTreeView() {
        let isHiding = !self.treeView.isHidden
        if !isHiding {
            self.treeView.isHidden = false
            self.treeViewResizer.isHidden = false
        } else {
            self.treeViewMinWidth.constant = 0
        }
        
        let defaultExpandedWidth: CGFloat = 200
        
        NSAnimationContext.runAnimationGroup({_ in
            NSAnimationContext.current.duration = 0.1
            NSAnimationContext.current.timingFunction =
                CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
            self.treeViewWidth.animator().constant = isHiding ? 0 : lastTreeViewWidth
            self.treeViewResizerWidth.animator().constant = isHiding ? 0 : 5
            self.openFilesWidth.animator().constant = isHiding ? 0 : 20
        }, completionHandler: {
            if isHiding {
                self.treeView.isHidden = true
                self.treeViewResizer.isHidden = true
            } else {
                self.treeViewMinWidth.constant = defaultExpandedWidth
            }
        })
    }
    
    override func increaseFontSize() {
        super.increaseFontSize()
        self.commandViewController?.increaseFontSize()
    }
    
    override func decreaseFontSize() {
        super.decreaseFontSize()
        self.commandViewController?.decreaseFontSize()
    }
    
    override func reload() {
        // undo/redo slider stuff
        self.undoSlider.max = Int(editor_buffer_get_undo_size(buf!))
        self.undoSlider.value = Int(editor_buffer_get_undo_index(buf!))

        self.globalUndoSlider.max = Int(editor_buffer_get_global_undo_size(buf!))
        self.globalUndoSlider.value = Int(editor_buffer_get_global_undo_index(buf!))
        
        // calculate height of buffer view and update if necessary
        let lineCount: Int64
        if preferences.virtualNewlines {
            lineCount = editor_buffer_get_line_count_virtual(buf!, preferences.virtualNewlineLength)
        } else {
            lineCount = editor_buffer_get_line_count(buf!)
        }

        let height = (CGFloat(lineCount) + 1) * preferences.charHeight
        if editorViewHeight.constant != height {
            editorViewHeight.constant = height
        }

        self.gutterView.needsDisplay = true

        // update gutter view dimensions
        if let gutterView = self.gutterView {
            if !preferences.showGutter {
                gutterViewWidth.constant = 0
                gutterView.isHidden = true
            } else {
                let charWidth = preferences.charWidth
                if buf != nil {
                    if lineCount < 11 {
                        gutterViewWidth.constant = charWidth * 3 + gutterView.margin * 2
                    } else {
                        let charCount = floor(log10(Double(lineCount - 1))) + 1
                        gutterViewWidth.constant = charWidth * CGFloat(charCount + 1) + gutterView.margin * 5
                    }
                } else {
                    gutterViewWidth.constant = charWidth * 2 + gutterView.margin * 2
                }
                gutterView.isHidden = false
            }
        }

        sort_and_merge_cursors(buf!)
        
        self.view.layer?.backgroundColor = preferences.editorBackgroundColor.cgColor
        
        updateFooterView()
        
        super.reload()
    }
    
    func updateFooterView() {
        // update labels
        let cursorCount = editor_buffer_get_cursor_count(buf!)
        if cursorCount > 1 {
            positionLabel.stringValue = "Multiple Cursors"
        } else {
            let line: Int64
            let column: Int64
            if self.preferences.virtualNewlines {
                line = editor_buffer_get_cursor_row_virtual(buf!, 0, preferences.virtualNewlineLength)
                column = editor_buffer_get_cursor_col_virtual(buf!, 0, preferences.virtualNewlineLength)
            } else {
                line = editor_buffer_get_cursor_row(buf!, 0)
                column = editor_buffer_get_cursor_col(buf!, 0)
            }
            positionLabel.stringValue = "Line \(line), Column \(column)"
        }
        
        modeLabel.stringValue = "\(self.mode.description())"
        
        // @todo(chad): is there a better place to put this wantsLayer stuff??
        // in viewDidLoad it is already too late :(
        if !self.footerView.wantsLayer { self.footerView.wantsLayer = true }
        self.footerView.layer?.backgroundColor = preferences.footerBackgroundColor.cgColor
    }
    
    func openFile() {
        let dialog = NSOpenPanel();
        
        dialog.title = "Choose a file"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = true
        dialog.canChooseDirectories = true
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false
        
        if dialog.runModal() == NSApplication.ModalResponse.OK {
            guard let result = dialog.url else { return }
            
            DispatchQueue.global(qos: .userInteractive).async {
                self.currentDirectory = result
                self.refreshOutlineItems(result)
                
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: result.path, isDirectory: &isDirectory) {
                    if !isDirectory.boolValue {
                        self.openFile(withURL: result)
                    }
                }
            }
        }
    }
    
    func openFile(withURL url: URL) {
        self.view.window?.title = url.lastPathComponent
        self.fileExtensionLabel.stringValue = ".\(url.pathExtension)"
        
        DispatchQueue.global(qos: .userInteractive).async {
            editor_buffer_open_file(self.buf!, UInt32(self.preferences.virtualNewlineLength), url.path)
            DispatchQueue.main.async {
                self.reload()
            }
        }
    }
    
    override func loadConfigFile() {
        super.loadConfigFile()
        
        self.positionLabel.textColor = preferences.footerTextColor
        self.modeLabel.textColor = preferences.footerTextColor
        self.fileExtensionLabel.textColor = preferences.footerTextColor
        
        self.positionLabel.font = preferences.editorFont
        self.modeLabel.font = preferences.editorFont
        self.fileExtensionLabel.font = preferences.editorFont
    }
    
    func save() {
        if editor_buffer_has_file_path(buf!) == 0 {
            saveAs()
        } else {
            editor_buffer_save_file(buf!)
        }
    }
    
    func saveAs() {
        let saveDialog = NSSavePanel();
        saveDialog.begin(completionHandler: { (result: NSApplication.ModalResponse) -> Void in
            if result == NSApplication.ModalResponse.OK {
                let filePath = saveDialog.url?.path
                editor_buffer_save_file_as(self.buf!, filePath)
            }
        })
    }
    
    func chooseFont(_ sender: Any) {
        let fontManager = NSFontManager.shared
        let panel = fontManager.fontPanel(true)
        panel?.makeKeyAndOrderFront(sender)
    }
    
    override func changeFont(_ sender: Any?) {
        if let fontManager = sender as? NSFontManager {
            preferences.editorFont = fontManager.convert(preferences.editorFont)
            reload()
        } else {
            Swift.print("error: could not cast sender to an NSFontManager")
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier?.rawValue != "commandPanel" { return }
        
        guard let dc = segue.destinationController as? SECommandPaneViewController else { return }
        dc.bufferVC = self
    }
    
}

extension SEBufferViewController: SESliderViewDelegate {
    func valueChanged(_ sliderView: SESliderView) {
        if sliderView == undoSlider {
            editor_buffer_undo(buf!, Int64(sliderView.savedValue))
            drawLastLine()
            reload()
        } else if sliderView == globalUndoSlider {
            editor_buffer_global_undo(buf!, Int64(sliderView.savedValue))
            drawLastLine()
            reload()
        }
        
        scrollToCursor()
    }
}

extension URL {
    var isDirectory: Bool {
        do {
            if let maybeIsDirectory = try self.resourceValues(forKeys: [.isDirectoryKey]).isDirectory {
                return maybeIsDirectory
            } else { return false }
        } catch {
            print("error: \(error)")
            return false
        }
    }
}
