import SwiftUI
import AppKit
import os.log
import Darwin

// MARK: - Custom Status Button

/// Custom button view that handles both left and right clicks
class CustomStatusButton: NSView {
    var target: AnyObject?
    var leftClickAction: Selector?
    var rightClickAction: Selector?
    
    override func mouseDown(with event: NSEvent) {
        // Left click - call the left click action
        if let target = target, let action = leftClickAction {
            target.perform(action, with: event)
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        // Right click - call the right click action
        if let target = target, let action = rightClickAction {
            target.perform(action, with: event)
        }
    }
    
    override func otherMouseDown(with event: NSEvent) {
        // Other mouse buttons - treat as right click
        if let target = target, let action = rightClickAction {
            target.perform(action, with: event)
        }
    }
}

@main
struct WorkspaceBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var presetHandler: PresetHandler?
    private let logger = Logger(subsystem: "com.macpresethandler.app", category: "AppDelegate")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("App launching")
        
        // Set up signal handlers to catch terminal termination
        signal(SIGTERM) { _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
        
        signal(SIGINT) { _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
        
        // Check if we have accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        logger.info("Accessibility enabled: \(accessEnabled)")
        
        // If accessibility is not enabled, show a helpful message
        if !accessEnabled {
            logger.warning("⚠️ Accessibility permissions not granted - login item registration may fail")
            // Show a helpful alert about permissions
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.showAccessibilityPermissionAlert()
            }
        }
        
        // Hide the dock icon since this is a menu bar app
        NSApp.setActivationPolicy(.accessory)
        
        // Create the status item (menu bar icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Create a custom white icon using system symbol
            let image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "Menu")
            
            // Apply white tint to make it white
            image?.isTemplate = true
            
            button.image = image
            button.imagePosition = .imageLeft
            
            // Set up both left-click (popover) and right-click (menu) handling
            setupButtonActions(for: button)
        } else {
            logger.error("Failed to get status button")
        }
        
        // Ensure the status item is visible
        statusItem?.isVisible = true
        
        // Create the popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .applicationDefined  // Changed from .transient to prevent auto-closing
        popover?.contentViewController = NSHostingController(rootView: ContentView().environmentObject(PresetHandler()))
        
        // Set the popover delegate to handle window management
        popover?.delegate = self
        
        // Initialize preset handler
        presetHandler = PresetHandler()
        
        // Register the app to start at login (only if not already registered) - do this asynchronously
        DispatchQueue.global(qos: .utility).async { [weak self] in
            if let self = self {
                logger.info("🔄 Checking startup registration status...")
                if !self.isRegisteredForLogin() {
                    logger.info("📝 App not registered for startup - attempting registration...")
                    self.registerForLogin()
                } else {
                    logger.info("✅ App is already registered for login")
                }
            }
        }
        
        // Register for system notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemWillPowerOff),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
        
        // Check if this is the first launch and show startup recommendation - do this asynchronously
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.checkFirstLaunchAndShowRecommendation()
        }
    }
    
    private func checkFirstLaunchAndShowRecommendation() {
        let defaults = UserDefaults.standard
        let hasLaunchedBefore = defaults.bool(forKey: "hasLaunchedBefore")
        
        if !hasLaunchedBefore {
            // First launch - show startup recommendation
            DispatchQueue.main.async { [weak self] in
                self?.showStartupRecommendation()
            }
            defaults.set(true, forKey: "hasLaunchedBefore")
        } else {
            // Not first launch - show simple confirmation
            DispatchQueue.main.async { [weak self] in
                self?.showRunningConfirmation()
            }
        }
    }
    
    private func showStartupRecommendation() {
        let alert = NSAlert()
        alert.messageText = "Welcome to Mac Preset Handler!"
        alert.informativeText = "We recommend you turn off automatic startup for other apps to improve your Mac's boot performance. This app will start automatically when you need it.\n\nYou can manage startup items in System Preferences > Users & Groups > Login Items."
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Not Now")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Open System Preferences to Login Items
            let script = """
            tell application "System Preferences"
                activate
                set current pane to pane id "com.apple.preference.users"
                reveal anchor "LoginItems"
            end tell
            """
            
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(nil)
            }
        }
    }
    
    private func showRunningConfirmation() {
        let alert = NSAlert()
        alert.messageText = "Mac Preset Handler is Running!"
        alert.informativeText = "The app will now start automatically when you boot your Mac. Check your menu bar for the list icon."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "Workspace-Buddy needs accessibility permissions to automatically start when you log in.\n\nTo enable this:\n1. Go to System Settings > Privacy & Security > Accessibility\n2. Click the lock icon and enter your password\n3. Add Workspace-Buddy to the list\n4. Restart the app"
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Settings to Accessibility
            let script = """
            tell application "System Settings"
                activate
                set current pane to pane id "com.apple.preference.security"
                reveal anchor "Privacy_Accessibility"
            end tell
            """
            
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(nil)
            }
        }
    }
    
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {
                // Show the popover
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                
                // Ensure the popover window is properly configured
                if let popoverWindow = popover?.contentViewController?.view.window {
                    popoverWindow.level = .floating  // Keep it above other windows
                    popoverWindow.makeKey()  // Make it the key window
                    
                    // Prevent the popover from being dismissed by clicking outside
                    popoverWindow.isMovableByWindowBackground = false
                }
            }
        }
    }
    
    // MARK: - System Notifications
    
    @objc func systemWillSleep(_ notification: Notification) {
        logger.info("System going to sleep - Mac Preset Handler will continue monitoring")
        // Save current state
        presetHandler?.savePresets()
        
        // Ensure the app stays active during sleep
        DispatchQueue.main.async { [weak self] in
            // Save presets before sleep
            self?.presetHandler?.savePresets()
        }
    }
    
    @objc func systemDidWake(_ notification: Notification) {
        logger.info("System woke up - Mac Preset Handler resuming full monitoring")
        
        // Resume full monitoring
        DispatchQueue.main.async { [weak self] in
            self?.presetHandler?.refreshPresets()
        }
    }
    
    @objc func systemWillPowerOff(_ notification: Notification) {
        logger.info("System powering off - Mac Preset Handler saving state")
        presetHandler?.savePresets()
    }
    
    // MARK: - Login Registration
    
    private func registerForLogin() {
        logger.info("🔄 Attempting to register for startup...")
        
        // Get the actual app path (resolve symlinks)
        let appPath = Bundle.main.bundlePath
        let resolvedPath = (appPath as NSString).resolvingSymlinksInPath
        logger.info("App path: \(resolvedPath)")
        
        // Check if we're already registered
        if isRegisteredForLogin() {
            logger.info("✅ App is already registered for startup")
            return
        }
        
        // Try multiple registration methods
        var registrationSuccess = false
        
        // Method 1: Try modern ServiceManagement API (requires code signing)
        if !registrationSuccess {
            registrationSuccess = registerUsingServiceManagement(appPath: resolvedPath)
        }
        
        // Method 2: Try AppleScript (requires accessibility permissions)
        if !registrationSuccess {
            registrationSuccess = registerUsingAppleScript(appPath: resolvedPath)
        }
        
        // Method 3: Try LaunchAgent as fallback
        if !registrationSuccess {
            do {
                try registerUsingAlternativeMethod(appPath: resolvedPath)
                registrationSuccess = true
                logger.info("✅ Fallback LaunchAgent registration successful")
            } catch {
                logger.error("❌ LaunchAgent registration failed: \(error)")
            }
        }
        
        if registrationSuccess {
            logger.info("✅ Successfully registered for startup using fallback method")
            // Verify registration
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.verifyStartupRegistration()
            }
        } else {
            logger.error("❌ All startup registration methods failed")
        }
    }
    
    private func addLoginItem(at appPath: String) throws -> Bool {
        // Try to use modern ServiceManagement API first
        let appURL = URL(fileURLWithPath: appPath)
        
        // Check if the app is already in login items
        let loginItems = try getLoginItems()
        for item in loginItems {
            if item.path == appPath {
                logger.info("App already in login items")
                return true
            }
        }
        
        // Add to login items
        let success = try addToLoginItems(appURL: appURL)
        return success
    }
    
    private func getLoginItems() throws -> [(name: String, path: String)] {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = [
            "-e", "tell application \"System Events\" to get the name of every login item"
        ]
        
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        
        try task.run()
        task.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        
        // Parse the output to get login item names
        let names = output.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        var items: [(name: String, path: String)] = []
        for name in names {
            if !name.isEmpty {
                // Get the path for each login item
                let pathTask = Process()
                pathTask.launchPath = "/usr/bin/osascript"
                pathTask.arguments = [
                    "-e", "tell application \"System Events\" to get the path of login item \"\(name)\""
                ]
                
                let pathPipe = Pipe()
                pathTask.standardOutput = pathPipe
                
                try pathTask.run()
                pathTask.waitUntilExit()
                
                let pathData = pathPipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: pathData, encoding: .utf8) ?? ""
                
                items.append((name: name, path: path.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }
        
        return items
    }
    
    private func registerUsingServiceManagement(appPath: String) -> Bool {
        // This method requires proper code signing and entitlements
        // For now, we'll return false and use fallback methods
        logger.info("ServiceManagement API not available (requires code signing)")
        return false
    }
    
    private func registerUsingAppleScript(appPath: String) -> Bool {
        do {
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = [
                "-e", "tell application \"System Events\" to make login item at end with properties {path:\"\(appPath)\", hidden:true}"
            ]
            
            try task.run()
            task.waitUntilExit()
            
            let success = task.terminationStatus == 0
            if success {
                logger.info("✅ AppleScript registration successful")
            } else {
                logger.warning("⚠️ AppleScript registration failed with status: \(task.terminationStatus)")
            }
            return success
        } catch {
            logger.error("❌ AppleScript registration error: \(error)")
            return false
        }
    }
    
    private func addToLoginItems(appURL: URL) throws -> Bool {
        return registerUsingAppleScript(appPath: appURL.path)
    }
    
    private func registerUsingAlternativeMethod(appPath: String) throws {
        // Alternative method using LaunchAgent as fallback
        let bundleID = Bundle.main.bundleIdentifier ?? "com.workspacebuddy.app"
        let loginItemPath = "~/Library/LaunchAgents/\(bundleID).plist"
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(bundleID)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(appPath)/Contents/MacOS/Workspace-Buddy</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>ProcessType</key>
            <string>Background</string>
            <key>StandardOutPath</key>
            <string>/tmp/workspacebuddy.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/workspacebuddy.error.log</string>
        </dict>
        </plist>
        """
        
        let launchAgentsPath = (loginItemPath as NSString).expandingTildeInPath
        let launchAgentsDir = (launchAgentsPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true)
        
        try plistContent.write(toFile: launchAgentsPath, atomically: true, encoding: .utf8)
        
        // Load the launch agent
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = ["load", launchAgentsPath]
        try process.run()
        process.waitUntilExit()
        
        logger.info("✅ Fallback LaunchAgent registration successful")
    }
    
    private func isRegisteredForLogin() -> Bool {
        // Multiple methods to check if we're registered
        let appPath = Bundle.main.bundlePath
        let resolvedPath = (appPath as NSString).resolvingSymlinksInPath
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Workspace-Buddy"
        
        // Method 1: Check using AppleScript (most reliable)
        let appleScriptCheck = checkLoginItemWithAppleScript(appPath: resolvedPath, appName: appName)
        if appleScriptCheck {
            logger.info("✅ Login item found via AppleScript check")
            return true
        }
        
        // Method 2: Check LaunchAgent files
        let launchAgentCheck = checkLaunchAgentFiles()
        if launchAgentCheck {
            logger.info("✅ Login item found via LaunchAgent check")
            return true
        }
        
        logger.info("❌ App not found in login items")
        return false
    }
    
    private func checkLoginItemWithAppleScript(appPath: String, appName: String) -> Bool {
        do {
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = [
                "-e", "tell application \"System Events\" to get the name of every login item whose path contains \"\(appPath)\""
            ]
            
            let outputPipe = Pipe()
            task.standardOutput = outputPipe
            
            try task.run()
            task.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            logger.error("AppleScript login check failed: \(error)")
            return false
        }
    }
    
    private func checkLaunchAgentFiles() -> Bool {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.workspacebuddy.app"
        let launchAgentPath = "~/Library/LaunchAgents/\(bundleID).plist"
        let expandedPath = (launchAgentPath as NSString).expandingTildeInPath
        
        return FileManager.default.fileExists(atPath: expandedPath)
    }
    
    /// Verify startup registration and fix if needed
    private func verifyStartupRegistration() {
        if !isRegisteredForLogin() {
            logger.warning("⚠️ Startup registration verification failed - attempting to re-register")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.registerForLogin()
            }
        } else {
            logger.info("✅ Startup registration verified successfully")
        }
    }
    
    /// Manual method to force re-register for startup (can be called from UI)
    @objc func forceReRegisterForStartup() {
        logger.info("🔄 Force re-registering for startup...")
        
        // Remove existing registration first
        removeStartupRegistration()
        
        // Wait a moment then re-register
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.registerForLogin()
        }
    }
    
    /// Fix startup registration (called from menu)
    @objc private func fixStartupRegistration() {
        forceReRegisterForStartup()
    }
    
    /// Request accessibility permissions (called from menu)
    @objc private func requestAccessibilityPermissions() {
        showAccessibilityPermissionAlert()
    }
    
    /// Remove from startup (called from menu)
    @objc private func removeFromStartup() {
        removeStartupRegistration()
    }
    
    /// Remove app from startup items
    private func removeStartupRegistration() {
        let appPath = Bundle.main.bundlePath
        
        // Simple removal using AppleScript
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = [
            "-e", "tell application \"System Events\" to delete login item \"Workspace-Buddy\""
        ]
        
        do {
            try task.run()
            task.waitUntilExit()
            logger.info("✅ Removed from startup items")
        } catch {
            logger.error("❌ Failed to remove from startup: \(error)")
        }
    }
    
    // MARK: - Context Menu Management
    
    /// Set up both left-click (popover) and right-click (menu) handling
    private func setupButtonActions(for button: NSStatusBarButton) {
        // Use direct target-action for instant response; no global event monitor
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        _ = button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    /// Single click handler that distinguishes left vs right click
    @objc private func statusItemClicked(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        
        if event.type == .rightMouseUp {
            let menu = createContextMenu()
            let popupPoint = NSPoint(x: 0, y: button.bounds.height - 2)
            menu.popUp(positioning: nil, at: popupPoint, in: button)
        } else {
            togglePopover()
        }
    }
    
    /// Create a dynamic context menu with current application information
    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Add Quit option
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add startup status and management
        let startupStatus = isRegisteredForLogin() ? "✅ Startup Enabled" : "❌ Startup Disabled"
        let startupHeader = NSMenuItem(title: startupStatus, action: nil, keyEquivalent: "")
        startupHeader.isEnabled = false
        menu.addItem(startupHeader)
        
        if !isRegisteredForLogin() {
            let fixStartupItem = NSMenuItem(title: "Fix Startup Registration", action: #selector(fixStartupRegistration), keyEquivalent: "")
            fixStartupItem.target = self
            menu.addItem(fixStartupItem)
            
            let permissionsItem = NSMenuItem(title: "Request Accessibility Permissions", action: #selector(requestAccessibilityPermissions), keyEquivalent: "")
            permissionsItem.target = self
            menu.addItem(permissionsItem)
        } else {
            let removeStartupItem = NSMenuItem(title: "Remove from Startup", action: #selector(removeFromStartup), keyEquivalent: "")
            removeStartupItem.target = self
            menu.addItem(removeStartupItem)
        }
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add "Quit All Applications" option
        let quitAllItem = NSMenuItem(title: "Quit All Applications", action: #selector(quitAllApplications), keyEquivalent: "")
        quitAllItem.target = self
        menu.addItem(quitAllItem)
        
        // Add "Quit Other Applications" option (apps not in current preset)
        let quitOthersItem = NSMenuItem(title: "Quit Other Applications", action: #selector(quitOtherApplications), keyEquivalent: "")
        quitOthersItem.target = self
        menu.addItem(quitOthersItem)
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add currently running applications section
        let runningAppsHeader = NSMenuItem(title: "Running Applications", action: nil, keyEquivalent: "")
        runningAppsHeader.isEnabled = false
        menu.addItem(runningAppsHeader)
        
        // Add running applications
        let runningApps = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular && app != NSApp
        }
        
        if runningApps.isEmpty {
            let noAppsItem = NSMenuItem(title: "No applications running", action: nil, keyEquivalent: "")
            noAppsItem.isEnabled = false
            menu.addItem(noAppsItem)
        } else {
            for app in runningApps.prefix(10) { // Limit to first 10 apps
                if let appName = app.localizedName {
                    let appItem = NSMenuItem(title: "Quit \(appName)", action: #selector(quitSpecificApp(_:)), keyEquivalent: "")
                    appItem.target = self
                    appItem.representedObject = app
                    menu.addItem(appItem)
                }
            }
            
            if runningApps.count > 10 {
                let moreItem = NSMenuItem(title: "... and \(runningApps.count - 10) more", action: nil, keyEquivalent: "")
                moreItem.isEnabled = false
                menu.addItem(moreItem)
            }
        }
        
        return menu
    }
    
    // MARK: - Application Management Methods
    
    /// Quit all running applications
    @objc private func quitAllApplications() {
        let alert = NSAlert()
        alert.messageText = "Quit All Applications"
        alert.informativeText = "Are you sure you want to quit all running applications? This will close all open apps including Workspace-Buddy."
        alert.addButton(withTitle: "Quit All")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let runningApps = NSWorkspace.shared.runningApplications.filter { app in
                app.activationPolicy == .regular && app != NSApp
            }
            
            for app in runningApps {
                app.terminate()
            }
            
            // Quit Workspace-Buddy last
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
        }
    }
    
    /// Quit applications that are not in the current preset
    @objc private func quitOtherApplications() {
        guard let currentPreset = presetHandler?.currentPreset else {
            let alert = NSAlert()
            alert.messageText = "No Active Preset"
            alert.informativeText = "Please activate a preset first to use this feature."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        let runningApps = NSWorkspace.shared.runningApplications.filter { app in
            guard let appName = app.localizedName else { return false }
            return app.activationPolicy == .regular && 
                   app != NSApp && 
                   !currentPreset.apps.contains { $0.name.lowercased() == appName.lowercased() }
        }
        
        if runningApps.isEmpty {
            let alert = NSAlert()
            alert.messageText = "No Other Applications"
            alert.informativeText = "All running applications are part of your current preset."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        let appNames = runningApps.compactMap { $0.localizedName }.joined(separator: "\n")
        let alert = NSAlert()
        alert.messageText = "Quit Other Applications"
        alert.informativeText = "The following applications are not in your current preset:\n\n\(appNames)\n\nWould you like to quit these applications?"
        alert.addButton(withTitle: "Quit Others")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            for app in runningApps {
                app.terminate()
            }
        }
    }
    
    /// Quit a specific application
    @objc private func quitSpecificApp(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? NSRunningApplication else { return }
        
        let alert = NSAlert()
        alert.messageText = "Quit \(app.localizedName ?? "Application")"
        alert.informativeText = "Are you sure you want to quit \(app.localizedName ?? "this application")?"
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            app.terminate()
        }
    }
    
    deinit {
        // Remove observers
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Critical App Lifecycle Methods
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Never terminate when windows are closed - this is a menu bar app
        return false
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Ensure the status item is visible when app becomes active
        statusItem?.isVisible = true
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Don't reopen windows when app is activated
        return false
    }
    
    func applicationSupportsSecureRestorableState(_ application: NSApplication) -> Bool {
        // Don't support restorable state for menu bar app
        return false
    }
    
    // Handle when the app is about to terminate (like when terminal closes)
    func applicationWillTerminate(_ notification: Notification) {
        // Save presets and clean up
        presetHandler?.savePresets()
        
        // Remove the status item
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        
        // Close the popover if it's open
        popover?.performClose(nil)
    }
}
