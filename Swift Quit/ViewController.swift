//
//  ViewController.swift
//  Swift Quit
//
//  Created by Johnny Baird on 5/25/22.
//

import Cocoa
import LaunchAtLogin

class ViewController: NSViewController, NSTableViewDelegate, NSWindowDelegate, NSDraggingDestination {
    @objc dynamic var launchAtLogin = LaunchAtLogin.kvo
    
    @IBOutlet weak var launchHiddenSwitch: NSSwitch!
    @IBOutlet weak var displayMenubarIcon: NSSwitch!
    @IBOutlet weak var excludeBehaviourPopupOutlet: NSPopUpButton!
    @IBOutlet weak var excludeBehaviourLabelOutlet: NSTextField!
    @IBOutlet weak var excludedAppsTableView: NSTableView!
    @IBOutlet weak var removeExcludedAppButtonOutlet: NSButton!
    @IBOutlet weak var launchAtLoginSwitch: NSSwitch!
    @IBOutlet weak var closeEmptyIfExemptedSwitch: NSSwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSApp.activate(ignoringOtherApps: true)
        view.window?.delegate = self
        
        setupViews()
        setupDragAndDrop()
        addDragAndDropHint()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    func setupViews() {
        print("launch at login:")
        print(launchAtLogin)
        
        if(swiftQuitSettings["menubarIconEnabled"] == "true"){
            displayMenubarIcon.state = NSControl.StateValue.on
        }
        
        if(swiftQuitSettings["launchHidden"] == "true"){
            launchHiddenSwitch.state = NSControl.StateValue.on
        }
        
        if(swiftQuitSettings["smartCloseEnabled"] == "true"){
            closeEmptyIfExemptedSwitch.state = .on
        } else {
            closeEmptyIfExemptedSwitch.state = .off
        }
        
        excludeBehaviourLabelOutlet.textColor = .labelColor
        
        if(swiftQuitSettings["excludeBehaviour"] == "excludeApps"){
            excludeBehaviourPopupOutlet.title = "All Apps Except The Following"
        }
        else{
            excludeBehaviourPopupOutlet.title = "The Following Apps"
        }
        
        excludedAppsTableView.dataSource = self
        excludedAppsTableView.delegate = self
        
    }
    
    func setupDragAndDrop() {
        // Register for app bundle and file URL drag types
        excludedAppsTableView.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])
        
        // Make the table view a valid drop target
        excludedAppsTableView.setDraggingSourceOperationMask(.copy, forLocal: false)
    }
    
    // MARK: - Drag and Drop Methods
    
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Check if the dragged item is an app bundle
        if isDraggingApp(sender) {
            return .copy
        }
        return []
    }
    
    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if isDraggingApp(sender) {
            return .copy
        }
        return []
    }
    
    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let fileURLs = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        
        var addedAny = false
        
        for url in fileURLs {
            if url.path.hasSuffix(".app") {
                // Check if the app is not already in the excluded list
                if !swiftQuitExcludedApps.contains(url.path) {
                    swiftQuitExcludedApps.append(url.path)
                    addedAny = true
                }
            }
        }
        
        if addedAny {
            // Update the table view
            excludedAppsTableView.reloadData()
            SwiftQuit.updateExcludedApps()
            return true
        }
        
        return false
    }
    
    private func isDraggingApp(_ sender: NSDraggingInfo) -> Bool {
        guard let fileURLs = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        
        // Check if any of the dragged items are applications
        return fileURLs.contains { url in
            return url.path.hasSuffix(".app")
        }
    }
    
    @IBAction func launchAtLoginToggle(_ sender: Any) {
        
        if launchAtLoginSwitch.state == NSControl.StateValue.on {
            SwiftQuit.enableLaunchAtLogin()
            LaunchAtLogin.isEnabled = true

        }
        else{
            SwiftQuit.disableLaunchAtLogin()
            LaunchAtLogin.isEnabled = false

        }
        
    }
    
    @IBAction func displayMenubarIconToggle(_ sender: Any) {
        
        if displayMenubarIcon.state == NSControl.StateValue.on {
            SwiftQuit.enableMenubarIcon()
            SwiftQuit.showMenu()
        }
        else{
            SwiftQuit.disableMenubarIcon()
            SwiftQuit.hideMenu()
            
            let disableMenubarAlert = NSAlert()
            disableMenubarAlert.messageText = "App Hidden from Menubar"
            disableMenubarAlert.informativeText = "If you need to access it, simply launch the app again to display the settings page."
            disableMenubarAlert.alertStyle = .informational
            disableMenubarAlert.addButton(withTitle: "OK")
            disableMenubarAlert.beginSheetModal(for: self.view.window!, completionHandler: nil)

        }
        
    }
    
    @IBAction func launchHiddenToggle(_ sender: Any) {
        
        if launchHiddenSwitch.state == NSControl.StateValue.on {
            SwiftQuit.enableLaunchHidden()
        }
        else{
            SwiftQuit.disableLaunchHidden()
        }
    }
    
    @IBAction func closeEmptyIfExemptedToggle(_ sender: Any) {
        if closeEmptyIfExemptedSwitch.state == .on {
            SwiftQuit.enableSmartClose()
        } else {
            SwiftQuit.disableSmartClose()
        }
    }
    
    @IBAction func changeExcludeBehaviour(_ sender: Any) {
        
        if(excludeBehaviourPopupOutlet.title == "All Apps Except The Following"){
            SwiftQuit.enableExcludedApps()
        }
        else{
            swiftQuitSettings["excludeBehaviour"] = "includeApps"
            SwiftQuit.enableIncludedApps()
        }
    }
    
    @IBAction func addExcludedApp(_ sender: Any) {
        let dialog = NSOpenPanel();
        let directory = URL(string: "file:///System/Applications/")
        
        dialog.title                   = "Choose Application";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canChooseFiles = true;
        dialog.canChooseDirectories = true;
        dialog.treatsFilePackagesAsDirectories = true
        dialog.directoryURL = directory
        
        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let result = dialog.url
            
            if (result != nil) {
                
                swiftQuitExcludedApps.append(result!.path)
                
                let count = swiftQuitExcludedApps.count - 1
                let indexSet = IndexSet(integer:count)
                
                excludedAppsTableView.beginUpdates()
                excludedAppsTableView.insertRows(at:indexSet, withAnimation:.effectFade)
                excludedAppsTableView.endUpdates()
                
                SwiftQuit.updateExcludedApps()
            }
        } else {
            return
        }
    }
    
    @IBAction func removeExcludedApp(_ sender: Any) {
        let row = excludedAppsTableView.selectedRow
        
        if(row != -1){
            
            let indexSet = IndexSet(integer:row)
            excludedAppsTableView.beginUpdates()
            swiftQuitExcludedApps.remove(at: row)
            excludedAppsTableView.removeRows(at:indexSet, withAnimation:.effectFade)
            excludedAppsTableView.endUpdates()
            
            if(swiftQuitExcludedApps.isEmpty){
                removeExcludedAppButtonOutlet.isHidden = true
            }
            
            SwiftQuit.updateExcludedApps()
        }
        
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectionCount = excludedAppsTableView.selectedRowIndexes.count
        if(selectionCount != 0){
            removeExcludedAppButtonOutlet.isHidden = false
        }
        else{
            removeExcludedAppButtonOutlet.isHidden = true
        }
    }
    
    func addDragAndDropHint() {
        // Create a hint text field
        let hintLabel = NSTextField()
        hintLabel.isEditable = false
        hintLabel.isBordered = false
        hintLabel.backgroundColor = .clear
        hintLabel.drawsBackground = false
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        hintLabel.stringValue = "Tip: Drag and drop applications directly to add them to the list"
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Position it at the bottom of the settings panel using Auto Layout
        if let tableView = excludedAppsTableView, let scrollView = tableView.enclosingScrollView {
            // Add to the container view rather than the table view itself
            let containerView = scrollView.superview!
            
            // Add hint label to view hierarchy
            containerView.addSubview(hintLabel)
            
            // Set up Auto Layout constraints to place it at the bottom
            NSLayoutConstraint.activate([
                hintLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                hintLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
                hintLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -20)
            ])
            
            // Tag it so we can find it later if needed
            hintLabel.tag = 1001
        }
    }
}

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return swiftQuitExcludedApps.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let application = swiftQuitExcludedApps[row]
        
        let columnIdentifier = tableColumn!.identifier.rawValue
        
        if columnIdentifier == "path" {
            return application
        } else {
            return nil
        }
    }
}

// Custom table view that accepts application drag and drop
class DragDestinationTableView: NSTableView {
    
    private var _isHighlightedForDrag = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])
        self.setDraggingSourceOperationMask(.copy, forLocal: false)
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let controller = self.delegate as? ViewController
        let dragOperation = controller?.draggingEntered(sender) ?? []
        
        if !dragOperation.isEmpty {
            _isHighlightedForDrag = true
            needsDisplay = true
        }
        
        return dragOperation
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        _isHighlightedForDrag = false
        needsDisplay = true
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let controller = self.delegate as? ViewController
        return controller?.draggingUpdated(sender) ?? []
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        _isHighlightedForDrag = false
        needsDisplay = true
        
        let controller = self.delegate as? ViewController
        return controller?.performDragOperation(sender) ?? false
    }
    
    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        // Visual update after drop
        self.reloadData()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if _isHighlightedForDrag {
            // Draw a highlight border when dragging valid app
            let borderWidth: CGFloat = 2.0
            let highlightColor = NSColor.systemBlue.withAlphaComponent(0.5)
            
            highlightColor.set()
            
            let borderRect = bounds.insetBy(dx: borderWidth/2, dy: borderWidth/2)
            let borderPath = NSBezierPath(roundedRect: borderRect, xRadius: 4, yRadius: 4)
            borderPath.lineWidth = borderWidth
            borderPath.stroke()
        }
    }
}
