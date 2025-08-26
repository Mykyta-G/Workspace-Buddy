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
        
        // Clean up any existing log files that might have been created
        cleanupExistingLogFiles()
        
        // Verify and fix LaunchAgent files to prevent log file creation
        verifyAndFixLaunchAgentFiles()
        
        // Check if we have accessibility permissions (only prompt once)
        let accessEnabled = checkAccessibilityPermissions()
        logger.info("Accessibility enabled: \(accessEnabled)")
        
        // Only show permission alert if we haven't asked before or if permissions were revoked
        let defaults = UserDefaults.standard
        let hasAskedForPermissions = defaults.bool(forKey: "hasAskedForPermissions")
        let permissionsWereGranted = defaults.bool(forKey: "accessibilityPermissionsGranted")
        
        if !accessEnabled && (!hasAskedForPermissions || permissionsWereGranted) {
            logger.warning("⚠️ Accessibility permissions not granted - login item registration may fail")
            // Show a helpful alert about permissions
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.showAccessibilityPermissionAlert()
            }
        } else if !accessEnabled && hasAskedForPermissions && !permissionsWereGranted {
            logger.info("ℹ️ User previously declined accessibility permissions - not showing alert again")
        }
        
        // Set as regular app so it appears in Launchpad and Applications
        NSApp.setActivationPolicy(.regular)
        
        // Hide the dock icon after a short delay to keep it as a menu bar app
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSApp.setActivationPolicy(.accessory)
        }
        
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
        popover?.behavior = .transient  // Allow closing by clicking outside
        popover?.contentViewController = NSHostingController(rootView: ContentView().environmentObject(PresetHandler.shared))
        
        // Set the popover delegate to handle window management
        popover?.delegate = self
        
        // Set up global event monitor to detect clicks outside the popover
        setupGlobalEventMonitor()
        
        // Initialize preset handler using singleton
        presetHandler = PresetHandler.shared
        
        // Ensure presets are properly loaded and saved on first launch (only if needed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkAndLoadPresetsIfNeeded()
            
            // Also force migrate any old-format presets to prevent overwrites
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.presetHandler?.forceMigrateCurrentPresets()
            }
        }
        
        // Monitor startup success and auto-repair if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.monitorStartupSuccess()
        }
        
        // Check for old format presets and auto-migrate to prevent overwrites
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.checkAndAutoMigrateOldFormatPresets()
        }
        
        // Register the app to start at login (only if not already registered) - do this asynchronously
        DispatchQueue.global(qos: .utility).async { [weak self] in
            if let self = self {
                logger.info("🔄 Checking startup registration status...")
                
                // Check if we've already tried to register recently to avoid repeated attempts
                let defaults = UserDefaults.standard
                let lastRegistrationAttempt = defaults.object(forKey: "lastStartupRegistrationAttempt") as? Date
                let timeSinceLastAttempt = lastRegistrationAttempt.map { Date().timeIntervalSince($0) } ?? 0
                let oneHour: TimeInterval = 60 * 60
                
                if !self.isRegisteredForLogin() && timeSinceLastAttempt > oneHour {
                    logger.info("📝 App not registered for startup - attempting registration...")
                    defaults.set(Date(), forKey: "lastStartupRegistrationAttempt")
                    self.registerForLogin()
                } else if !self.isRegisteredForLogin() && timeSinceLastAttempt <= oneHour {
                    logger.info("⏰ Startup registration attempted recently, waiting before retry...")
                } else {
                    logger.info("✅ App is already registered for startup")
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
    
    private func checkAndLoadPresetsIfNeeded() {
        let defaults = UserDefaults.standard
        let hasInitializedPresets = defaults.bool(forKey: "hasInitializedPresets")
        let hasUserCreatedPresets = defaults.bool(forKey: "hasUserCreatedPresets")
        
        if !hasInitializedPresets {
            // First time ever - initialize presets safely
            logger.info("🔄 First time initialization - setting up presets safely")
            presetHandler?.safeInitializePresets()
            defaults.set(true, forKey: "hasInitializedPresets")
        } else if hasUserCreatedPresets {
            // We have user-created presets - preserve them
            logger.info("✅ App has user-created presets - preserving them")
            presetHandler?.forceRefreshPresets()
        } else {
            // Not first time and no user presets - check if we actually have presets file
            logger.info("✅ App has been initialized before - checking for existing presets file...")
            
            // Check if presets file exists and has content
            if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let presetsFileURL = documentsPath.appendingPathComponent("presets.json")
                if FileManager.default.fileExists(atPath: presetsFileURL.path) {
                    logger.info("✅ Found existing presets file - loading and preserving user presets")
                    // We have a presets file, so load it and mark as user-created
                    presetHandler?.forceRefreshPresets()
                    
                    // Mark that we have user-created presets to prevent future overwrites
                    defaults.set(true, forKey: "hasUserCreatedPresets")
                    defaults.set(Date(), forKey: "lastPresetSaveDate")
                    logger.info("✅ Marked existing presets as user-created to prevent future overwrites")
                } else {
                    logger.info("📂 No presets file found - using defaults temporarily")
                    presetHandler?.forceRefreshPresets()
                }
            } else {
                logger.info("✅ App has been initialized before - loading existing presets conservatively")
                presetHandler?.forceRefreshPresets()
            }
        }
        
        // CRITICAL FIX: Always check for existing presets file and preserve user changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.forcePreserveExistingPresets()
        }
    }
    
    /// Check if presets need to be migrated (only called when explicitly requested)
    private func checkPresetMigrationIfNeeded() {
        let defaults = UserDefaults.standard
        let needsMigrationCheck = defaults.bool(forKey: "needsPresetMigrationCheck")
        
        if needsMigrationCheck {
            logger.info("🔄 Preset migration check needed - performing migration")
            presetHandler?.forceResetAndMigrate()
            defaults.set(false, forKey: "needsPresetMigrationCheck")
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
        }
        // Don't show alerts on subsequent launches - just run silently
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
        alert.addButton(withTitle: "Don't Ask Again")
        
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
        } else if response == .alertThirdButtonReturn {
            // User clicked "Don't Ask Again"
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: "userDeclinedStartupRegistration")
            logger.info("ℹ️ User declined startup registration permanently")
        }
    }
    
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                closePopover()
            } else {
                // Show dock icon when popover opens (makes app more discoverable)
                NSApp.setActivationPolicy(.regular)
                
                // Show the popover
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                
                // Ensure the popover window is properly configured
                if let popoverWindow = popover?.contentViewController?.view.window {
                    popoverWindow.level = .floating  // Keep it above other windows
                    popoverWindow.makeKey()  // Make it the key window
                    popoverWindow.isMovableByWindowBackground = false
                }
            }
        }
    }
    
    // MARK: - System Notifications
    
    @objc func systemWillSleep(_ notification: Notification) {
        logger.info("System going to sleep - Mac Preset Handler will continue monitoring")
        // Save current state
        presetHandler?.forceSavePresets()
        
        // Ensure the app stays active during sleep
        DispatchQueue.main.async { [weak self] in
            // Save presets before sleep
            self?.presetHandler?.forceSavePresets()
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
        presetHandler?.forceSavePresets()
    }
    
    // MARK: - Accessibility Permissions
    
    private func checkAccessibilityPermissions() -> Bool {
        let defaults = UserDefaults.standard
        let hasAskedForPermissions = defaults.bool(forKey: "hasAskedForPermissions")
        let permissionsGranted = defaults.bool(forKey: "accessibilityPermissionsGranted")
        
        // If we've already asked and permissions were granted, just check current status without prompting
        if hasAskedForPermissions && permissionsGranted {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false]
            let currentStatus = AXIsProcessTrustedWithOptions(options as CFDictionary)
            
            // Update stored status if it changed
            if currentStatus != permissionsGranted {
                defaults.set(currentStatus, forKey: "accessibilityPermissionsGranted")
            }
            
            return currentStatus
        } else if hasAskedForPermissions && !permissionsGranted {
            // We've asked before but permissions weren't granted - don't ask again
            // Just check current status silently
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false]
            let currentStatus = AXIsProcessTrustedWithOptions(options as CFDictionary)
            
            // Update stored status
            defaults.set(currentStatus, forKey: "accessibilityPermissionsGranted")
            
            return currentStatus
        } else {
            // First time asking - prompt the user and remember
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
            let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
            
            // Remember that we've asked and the result
            defaults.set(true, forKey: "hasAskedForPermissions")
            defaults.set(accessEnabled, forKey: "accessibilityPermissionsGranted")
            
            // Also store the timestamp to avoid asking too frequently
            defaults.set(Date(), forKey: "lastPermissionRequestDate")
            
            return accessEnabled
        }
    }
    
    /// Check if accessibility permissions are currently granted (without prompting)
    private func hasAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// Check if we should show permission alerts (avoid showing too frequently)
    private func shouldShowPermissionAlerts() -> Bool {
        let defaults = UserDefaults.standard
        let lastRequest = defaults.object(forKey: "lastPermissionRequestDate") as? Date
        
        // If we've never asked, or it's been more than 24 hours, we can show alerts
        guard let lastRequest = lastRequest else { return true }
        
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
        let twentyFourHours: TimeInterval = 24 * 60 * 60
        
        return timeSinceLastRequest > twentyFourHours
    }
    
    // MARK: - Popover Management
    
    private var globalEventMonitor: Any?
    
    private func setupGlobalEventMonitor() {
        // Monitor global mouse events to detect clicks outside the popover
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            self?.handleGlobalEvent(event)
        }
    }
    
    private func handleGlobalEvent(_ event: NSEvent) {
        guard let popover = popover, popover.isShown else { return }
        
        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            handleGlobalMouseEvent(event)
        case .keyDown:
            handleGlobalKeyEvent(event)
        default:
            break
        }
    }
    
    private func handleGlobalMouseEvent(_ event: NSEvent) {
        guard let popover = popover, popover.isShown else { return }
        
        // Get the popover window
        guard let popoverWindow = popover.contentViewController?.view.window else { return }
        
        // Convert the global event location to the popover window's coordinate system
        let eventLocationInWindow = popoverWindow.convertPoint(fromScreen: event.locationInWindow)
        
        // Check if the click is outside the popover window
        if !popoverWindow.frame.contains(eventLocationInWindow) {
            // Click is outside the popover - close it
            DispatchQueue.main.async { [weak self] in
                self?.closePopover()
            }
        }
    }
    
    private func handleGlobalKeyEvent(_ event: NSEvent) {
        // Close popover on Escape key
        if event.keyCode == 53 { // Escape key
            DispatchQueue.main.async { [weak self] in
                self?.closePopover()
            }
        }
    }
    
    private func handleStatusButtonClick() {
        // If popover is already open, close it
        if popover?.isShown == true {
            closePopover()
        } else {
            // Otherwise, toggle it open
            togglePopover()
        }
    }
    
    private func closePopover() {
        popover?.performClose(nil)
        // Hide dock icon when popover closes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    // MARK: - NSPopoverDelegate
    
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        // Allow the popover to close when requested
        return true
    }
    
    func popoverDidShow(_ notification: Notification) {
        // Popover is now visible - ensure it's properly configured
        if let popoverWindow = popover?.contentViewController?.view.window {
            popoverWindow.level = .floating
            popoverWindow.makeKey()
        }
    }
    
    func popoverDidClose(_ notification: Notification) {
        // Popover has closed - clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    

    
    // MARK: - Login Registration
    
    private func registerForLogin() {
        logger.info("🔄 Starting bulletproof startup registration...")
        
        // Check if user has explicitly declined startup registration
        let defaults = UserDefaults.standard
        let userDeclinedStartup = defaults.bool(forKey: "userDeclinedStartupRegistration")
        if userDeclinedStartup {
            logger.info("ℹ️ User has declined startup registration - not attempting again")
            return
        }
        
        // Get the actual app path (resolve symlinks)
        let appPath = Bundle.main.bundlePath
        let resolvedPath = (appPath as NSString).resolvingSymlinksInPath
        logger.info("App path: \(resolvedPath)")
        
        // Check if we're already registered
        if isRegisteredForLogin() {
            logger.info("✅ App is already registered for startup")
            return
        }
        
        // BULLETPROOF REGISTRATION - Try ALL methods simultaneously
        var registrationSuccess = false
        var successfulMethods: [String] = []
        
        // Method 1: LaunchAgent (Most Reliable)
        do {
            try registerUsingLaunchAgent(appPath: resolvedPath)
            registrationSuccess = true
            successfulMethods.append("LaunchAgent")
            logger.info("✅ LaunchAgent registration successful")
        } catch {
            logger.error("❌ LaunchAgent registration failed: \(error)")
        }
        
        // Method 2: Login Items (Backup)
        if registerUsingLoginItems(appPath: resolvedPath) {
            registrationSuccess = true
            successfulMethods.append("Login Items")
            logger.info("✅ Login Items registration successful")
        } else {
            logger.error("❌ Login Items registration failed")
        }
        
        // Method 3: Manual Startup Script (Nuclear Option)
        if createManualStartupScript(appPath: resolvedPath) {
            registrationSuccess = true
            successfulMethods.append("Manual Script")
            logger.info("✅ Manual startup script created")
        } else {
            logger.error("❌ Manual startup script creation failed")
        }
        
        if registrationSuccess {
            logger.info("✅ Startup registration successful using: \(successfulMethods.joined(separator: ", "))")
            
            // Force verification and repair if needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.forceVerifyAndRepairStartup()
            }
        } else {
            logger.error("❌ All startup registration methods failed - using emergency fallback")
            createEmergencyStartupFallback(appPath: resolvedPath)
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
    
    // MARK: - Bulletproof Startup Registration Methods
    
    /// Register using LaunchAgent (Most Reliable Method)
    private func registerUsingLaunchAgent(appPath: String) throws {
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
            <key>EnvironmentVariables</key>
            <dict>
                <key>PATH</key>
                <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
            </dict>
            <key>LimitLoadToSessionType</key>
            <array>
                <string>Aqua</string>
            </array>
            <key>ThrottleInterval</key>
            <integer>10</integer>
        </dict>
        </plist>
        """
        
        let launchAgentsPath = (loginItemPath as NSString).expandingTildeInPath
        let launchAgentsDir = (launchAgentsPath as NSString).deletingLastPathComponent
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true)
        
        // Write the plist file
        try plistContent.write(toFile: launchAgentsPath, atomically: true, encoding: .utf8)
        
        // Load the launch agent
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = ["load", launchAgentsPath]
        try process.run()
        process.waitUntilExit()
        
        // Verify the launch agent was loaded
        let verifyProcess = Process()
        verifyProcess.launchPath = "/bin/launchctl"
        verifyProcess.arguments = ["list", bundleID]
        try verifyProcess.run()
        verifyProcess.waitUntilExit()
        
        if verifyProcess.terminationStatus != 0 {
            throw NSError(domain: "LaunchAgent", code: 1, userInfo: [NSLocalizedDescriptionKey: "LaunchAgent verification failed"])
        }
        
        // Store successful registration to avoid re-prompting
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "startupRegistrationSuccessful")
        defaults.set(Date(), forKey: "lastStartupRegistrationDate")
        
        logger.info("✅ LaunchAgent registration and verification successful")
    }
    
    /// Register using Login Items (Backup Method)
    private func registerUsingLoginItems(appPath: String) -> Bool {
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
                logger.info("✅ Login Items registration successful")
            } else {
                logger.warning("⚠️ Login Items registration failed with status: \(task.terminationStatus)")
            }
            return success
        } catch {
            logger.error("❌ Login Items registration error: \(error)")
            return false
        }
    }
    
    /// Create manual startup script (Nuclear Option)
    private func createManualStartupScript(appPath: String) -> Bool {
        let scriptContent = """
        #!/bin/bash
        # Workspace-Buddy Auto-Startup Script
        # Created automatically - DO NOT EDIT
        
        # Wait for system to fully boot
        sleep 10
        
        # Check if app is already running
        if ! pgrep -f "Workspace-Buddy" > /dev/null; then
            # Launch the app (use -a flag to prevent Finder from opening)
            open -a "\(appPath)"
        fi
        """
        
        let scriptPath = "~/Library/LaunchAgents/workspacebuddy-startup.sh"
        let expandedPath = (scriptPath as NSString).expandingTildeInPath
        
        do {
            try scriptContent.write(toFile: expandedPath, atomically: true, encoding: .utf8)
            
            // Make it executable
            let chmodProcess = Process()
            chmodProcess.launchPath = "/bin/chmod"
            chmodProcess.arguments = ["+x", expandedPath]
            try chmodProcess.run()
            chmodProcess.waitUntilExit()
            
            // Create a LaunchAgent to run this script
            let plistContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTD/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.workspacebuddy.startupscript</string>
                <key>ProgramArguments</key>
                <array>
                    <string>/bin/bash</string>
                    <string>\(expandedPath)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
                <key>StartInterval</key>
                <integer>60</integer>
            </dict>
            </plist>
            """
            
            let plistPath = "~/Library/LaunchAgents/com.workspacebuddy.startupscript.plist"
            let expandedPlistPath = (plistPath as NSString).expandingTildeInPath
            
            try plistContent.write(toFile: expandedPlistPath, atomically: true, encoding: .utf8)
            
            // Load the launch agent
            let process = Process()
            process.launchPath = "/bin/launchctl"
            process.arguments = ["load", expandedPlistPath]
            try process.run()
            process.waitUntilExit()
            
            logger.info("✅ Manual startup script created and loaded")
            return true
        } catch {
            logger.error("❌ Manual startup script creation failed: \(error)")
            return false
        }
    }
    
    /// Emergency startup fallback (Last Resort)
    private func createEmergencyStartupFallback(appPath: String) {
        logger.warning("🚨 Using emergency startup fallback")
        
        // Create a simple shell script in user's home directory
        let scriptContent = """
        #!/bin/bash
        # Emergency Workspace-Buddy Startup
        sleep 15
        open -a "\(appPath)"
        """
        
        let scriptPath = "~/startup-workspacebuddy.sh"
        let expandedPath = (scriptPath as NSString).expandingTildeInPath
        
        do {
            try scriptContent.write(toFile: expandedPath, atomically: true, encoding: .utf8)
            
            // Make executable
            let chmodProcess = Process()
            chmodProcess.launchPath = "/bin/chmod"
            chmodProcess.arguments = ["+x", expandedPath]
            try chmodProcess.run()
            chmodProcess.waitUntilExit()
            
            // Add to user's shell profile
            let profilePath = "~/.zshrc"
            let expandedProfilePath = (profilePath as NSString).expandingTildeInPath
            
            let profileContent = "\n# Workspace-Buddy Emergency Startup\n\(expandedPath) &\n"
            
            if let existingContent = try? String(contentsOfFile: expandedProfilePath, encoding: .utf8) {
                try (existingContent + profileContent).write(toFile: expandedProfilePath, atomically: true, encoding: .utf8)
            } else {
                try profileContent.write(toFile: expandedProfilePath, atomically: true, encoding: .utf8)
            }
            
            logger.info("✅ Emergency startup fallback created")
        } catch {
            logger.error("❌ Emergency startup fallback failed: \(error)")
        }
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
    
    /// Force verification and repair of startup registration
    private func forceVerifyAndRepairStartup() {
        logger.info("🔍 Force verifying startup registration...")
        
        let appPath = Bundle.main.bundlePath
        let resolvedPath = (appPath as NSString).resolvingSymlinksInPath
        
        // Check all possible startup methods
        var startupMethods: [String: Bool] = [:]
        
        // Check LaunchAgent
        startupMethods["LaunchAgent"] = checkLaunchAgentStatus()
        
        // Check Login Items
        startupMethods["Login Items"] = checkLoginItemsStatus(appPath: resolvedPath)
        
        // Check Manual Script
        startupMethods["Manual Script"] = checkManualScriptStatus()
        
        // Check Emergency Fallback
        startupMethods["Emergency Fallback"] = checkEmergencyFallbackStatus()
        
        // Log status
        for (method, status) in startupMethods {
            logger.info("\(status ? "✅" : "❌") \(method): \(status ? "Working" : "Failed")")
        }
        
        // If any method is working, we're good
        if startupMethods.values.contains(true) {
            logger.info("✅ At least one startup method is working")
            return
        }
        
        // If all methods failed, force re-registration
        logger.warning("🚨 All startup methods failed - forcing re-registration")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.registerForLogin()
        }
    }
    
    /// Check LaunchAgent status
    private func checkLaunchAgentStatus() -> Bool {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.workspacebuddy.app"
        
        do {
            let process = Process()
            process.launchPath = "/bin/launchctl"
            process.arguments = ["list", bundleID]
            try process.run()
            process.waitUntilExit()
            
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    /// Check Login Items status
    private func checkLoginItemsStatus(appPath: String) -> Bool {
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
            return false
        }
    }
    
    /// Check Manual Script status
    private func checkManualScriptStatus() -> Bool {
        let scriptPath = "~/Library/LaunchAgents/workspacebuddy-startup.sh"
        let expandedPath = (scriptPath as NSString).expandingTildeInPath
        
        return FileManager.default.fileExists(atPath: expandedPath)
    }
    
    /// Check Emergency Fallback status
    private func checkEmergencyFallbackStatus() -> Bool {
        let scriptPath = "~/startup-workspacebuddy.sh"
        let expandedPath = (scriptPath as NSString).expandingTildeInPath
        
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
        // Reset permission memory and request again
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "hasAskedForPermissions")
        defaults.removeObject(forKey: "accessibilityPermissionsGranted")
        
        // Now check permissions (this will prompt the user)
        let accessEnabled = checkAccessibilityPermissions()
        
        if accessEnabled {
            let alert = NSAlert()
            alert.messageText = "Permissions Granted"
            alert.informativeText = "Accessibility permissions have been granted. The app should now work properly with startup registration."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    /// Reset permission memory (called from menu)
    @objc private func resetPermissionMemory() {
        let alert = NSAlert()
        alert.messageText = "Reset Permission Memory"
        alert.informativeText = "This will reset the app's memory of accessibility permissions. You'll be asked for permissions again on the next restart, but this can help if permissions aren't working correctly."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "hasAskedForPermissions")
            defaults.removeObject(forKey: "accessibilityPermissionsGranted")
            
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Permission Memory Reset"
            confirmAlert.informativeText = "Permission memory has been reset. You'll be asked for accessibility permissions again on the next restart."
            confirmAlert.addButton(withTitle: "OK")
            confirmAlert.runModal()
        }
    }
    
    /// Open System Settings to Accessibility section (called from menu)
    @objc private func openAccessibilitySettings() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-b", "com.apple.systempreferences", "/System/Library/PreferencePanes/Security.prefPane"]
        
        do {
            try task.run()
            logger.info("✅ Opened System Settings > Privacy & Security")
        } catch {
            logger.error("❌ Failed to open System Settings: \(error)")
            
            // Fallback: just open System Settings
            let fallbackTask = Process()
            fallbackTask.launchPath = "/usr/bin/open"
            fallbackTask.arguments = ["-b", "com.apple.systempreferences"]
            
            do {
                try fallbackTask.run()
            } catch {
                logger.error("❌ Failed to open System Settings (fallback): \(error)")
            }
        }
    }
    
    /// Check if preset migration is needed (called from menu)
    @objc private func checkPresetMigration() {
        let alert = NSAlert()
        alert.messageText = "Check Preset Migration"
        alert.informativeText = "This will check if your presets need to be migrated to the new format without overwriting your current changes."
        alert.addButton(withTitle: "Check")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if presetHandler?.checkMigrationNeeded() == true {
                let migrationAlert = NSAlert()
                migrationAlert.messageText = "Migration Needed"
                migrationAlert.informativeText = "Your presets need to be migrated to the new format. This will preserve your current settings."
                migrationAlert.addButton(withTitle: "Migrate Now")
                migrationAlert.addButton(withTitle: "Later")
                migrationAlert.alertStyle = .warning
                
                let migrationResponse = migrationAlert.runModal()
                if migrationResponse == .alertFirstButtonReturn {
                    presetHandler?.forceResetAndMigrate()
                    
                    let confirmAlert = NSAlert()
                    confirmAlert.messageText = "Migration Complete"
                    confirmAlert.informativeText = "Your presets have been successfully migrated to the new format."
                    confirmAlert.addButton(withTitle: "OK")
                    confirmAlert.runModal()
                }
            } else {
                let noMigrationAlert = NSAlert()
                noMigrationAlert.messageText = "No Migration Needed"
                noMigrationAlert.informativeText = "Your presets are already in the current format. No migration is required."
                noMigrationAlert.addButton(withTitle: "OK")
                noMigrationAlert.runModal()
            }
        }
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
    
    /// Reset and migrate presets (called from menu)
    @objc private func resetAndMigratePresets() {
        logger.info("🔄 User requested preset reset and migration")
        
        let alert = NSAlert()
        alert.messageText = "Reset and Migrate Presets"
        alert.informativeText = "This will attempt to migrate your existing presets to the new format and fix any data corruption issues. Your current presets will be preserved if possible."
        alert.addButton(withTitle: "Reset and Migrate")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Trigger the reset and migration
            presetHandler?.forceResetAndMigrate()
            
            // Show confirmation
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Reset Complete"
            confirmAlert.informativeText = "Your presets have been reset and migrated. The app will now use the new format for better reliability."
            confirmAlert.addButton(withTitle: "OK")
            confirmAlert.runModal()
        }
    }
    
    /// Force migrate current presets to prevent overwrites (called from menu)
    @objc private func forceMigrateCurrentPresets() {
        logger.info("🔄 User requested force migration of current presets")
        
        let alert = NSAlert()
        alert.messageText = "Force Migrate Current Presets"
        alert.informativeText = "This will migrate your current presets from the old format to the new format to prevent them from being overwritten on reboot. Your presets will be preserved."
        alert.addButton(withTitle: "Migrate Now")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Trigger the force migration
            presetHandler?.forceMigrateCurrentPresets()
            
            // Show confirmation
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Migration Complete"
            confirmAlert.informativeText = "Your presets have been migrated to the new format. They will no longer be overwritten on reboot."
            confirmAlert.addButton(withTitle: "OK")
            confirmAlert.runModal()
        }
    }
    
    /// Show startup status and repair options (called from menu)
    @objc private func showStartupStatusAndRepair() {
        logger.info("🔍 User requested startup status and repair")
        
        let appPath = Bundle.main.bundlePath
        let resolvedPath = (appPath as NSString).resolvingSymlinksInPath
        
        // Check all startup methods
        var startupMethods: [String: Bool] = [:]
        startupMethods["LaunchAgent"] = checkLaunchAgentStatus()
        startupMethods["Login Items"] = checkLoginItemsStatus(appPath: resolvedPath)
        startupMethods["Manual Script"] = checkManualScriptStatus()
        startupMethods["Emergency Fallback"] = checkEmergencyFallbackStatus()
        
        // Build status message
        var statusMessage = "Current Startup Status:\n\n"
        var workingMethods: [String] = []
        var failedMethods: [String] = []
        
        for (method, status) in startupMethods {
            if status {
                workingMethods.append(method)
                statusMessage += "✅ \(method): Working\n"
            } else {
                failedMethods.append(method)
                statusMessage += "❌ \(method): Failed\n"
            }
        }
        
        statusMessage += "\n"
        
        if workingMethods.isEmpty {
            statusMessage += "🚨 NO STARTUP METHODS ARE WORKING!\n\n"
            statusMessage += "This means the app will NOT start automatically when you reboot.\n\n"
            statusMessage += "Recommended Actions:\n"
            statusMessage += "1. Click 'Force Repair All Methods' to attempt automatic fix\n"
            statusMessage += "2. Check System Settings > Privacy & Security > Accessibility\n"
            statusMessage += "3. Ensure Workspace-Buddy has accessibility permissions\n"
        } else {
            statusMessage += "✅ Startup is working! The app will start automatically.\n\n"
            statusMessage += "Working methods: \(workingMethods.joined(separator: ", "))\n"
            if !failedMethods.isEmpty {
                statusMessage += "Failed methods: \(failedMethods.joined(separator: ", "))\n"
            }
        }
        
        // Create alert with options
        let alert = NSAlert()
        alert.messageText = "Workspace-Buddy Startup Status"
        alert.informativeText = statusMessage
        alert.alertStyle = workingMethods.isEmpty ? .critical : .informational
        
        if workingMethods.isEmpty {
            alert.addButton(withTitle: "Force Repair All Methods")
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
        } else {
            alert.addButton(withTitle: "Repair Failed Methods")
            alert.addButton(withTitle: "OK")
        }
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            if workingMethods.isEmpty {
                // Force repair all methods
                logger.info("🔄 User requested force repair of all startup methods")
                forceRepairAllStartupMethods()
            } else {
                // Repair only failed methods
                logger.info("🔄 User requested repair of failed startup methods")
                repairFailedStartupMethods(failedMethods: failedMethods)
            }
        } else if response == .alertSecondButtonReturn && workingMethods.isEmpty {
            // Open System Settings
            openSystemSettings()
        }
    }
    
    /// Force repair all startup methods
    private func forceRepairAllStartupMethods() {
        logger.info("🚨 Force repairing all startup methods...")
        
        // Remove all existing startup registrations
        removeAllStartupRegistrations()
        
        // Wait a moment then re-register
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.registerForLogin()
            
            // Show confirmation after repair attempt
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.showStartupStatusAndRepair()
            }
        }
    }
    
    /// Repair only failed startup methods
    private func repairFailedStartupMethods(failedMethods: [String]) {
        logger.info("🔧 Repairing failed startup methods: \(failedMethods)")
        
        let appPath = Bundle.main.bundlePath
        let resolvedPath = (appPath as NSString).resolvingSymlinksInPath
        
        for method in failedMethods {
            switch method {
            case "LaunchAgent":
                do {
                    try registerUsingLaunchAgent(appPath: resolvedPath)
                    logger.info("✅ LaunchAgent repair successful")
                } catch {
                    logger.error("❌ LaunchAgent repair failed: \(error)")
                }
            case "Login Items":
                if registerUsingLoginItems(appPath: resolvedPath) {
                    logger.info("✅ Login Items repair successful")
                } else {
                    logger.error("❌ Login Items repair failed")
                }
            case "Manual Script":
                if createManualStartupScript(appPath: resolvedPath) {
                    logger.info("✅ Manual Script repair successful")
                } else {
                    logger.error("❌ Manual Script repair failed")
                }
            case "Emergency Fallback":
                createEmergencyStartupFallback(appPath: resolvedPath)
                logger.info("✅ Emergency Fallback repair attempted")
            default:
                break
            }
        }
        
        // Show updated status
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showStartupStatusAndRepair()
        }
    }
    
    /// Remove all startup registrations
    private func removeAllStartupRegistrations() {
        logger.info("🧹 Removing all startup registrations...")
        
        let bundleID = Bundle.main.bundleIdentifier ?? "com.workspacebuddy.app"
        
        // Remove LaunchAgent
        do {
            let process = Process()
            process.launchPath = "/bin/launchctl"
            process.arguments = ["unload", "~/Library/LaunchAgents/\(bundleID).plist"]
            try process.run()
            process.waitUntilExit()
            logger.info("✅ LaunchAgent unloaded")
        } catch {
            logger.warning("⚠️ Could not unload LaunchAgent: \(error)")
        }
        
        // Remove manual script LaunchAgent
        do {
            let process = Process()
            process.launchPath = "/bin/launchctl"
            process.arguments = ["unload", "~/Library/LaunchAgents/com.workspacebuddy.startupscript.plist"]
            try process.run()
            process.waitUntilExit()
            logger.info("✅ Manual script LaunchAgent unloaded")
        } catch {
            logger.warning("⚠️ Could not unload manual script LaunchAgent: \(error)")
        }
        
        // Remove from Login Items
        do {
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = [
                "-e", "tell application \"System Events\" to delete login item \"Workspace-Buddy\""
            ]
            try task.run()
            task.waitUntilExit()
            logger.info("✅ Removed from Login Items")
        } catch {
            logger.warning("⚠️ Could not remove from Login Items: \(error)")
        }
        
        // Clean up files
        let fileManager = FileManager.default
        let paths = [
            "~/Library/LaunchAgents/\(bundleID).plist",
            "~/Library/LaunchAgents/com.workspacebuddy.startupscript.plist",
            "~/Library/LaunchAgents/workspacebuddy-startup.sh",
            "~/startup-workspacebuddy.sh"
        ]
        
        for path in paths {
            let expandedPath = (path as NSString).expandingTildeInPath
            if fileManager.fileExists(atPath: expandedPath) {
                try? fileManager.removeItem(atPath: expandedPath)
                logger.info("✅ Removed file: \(expandedPath)")
            }
        }
    }
    
    /// Open System Settings to Accessibility
    private func openSystemSettings() {
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
    
    /// Show diagnostic information (called from menu)
    @objc private func showDiagnosticInfo() {
        logger.info("🔍 User requested diagnostic information")
        
        guard let diagnosticInfo = presetHandler?.getDiagnosticInfo() else {
            let alert = NSAlert()
            alert.messageText = "Diagnostic Information Unavailable"
            alert.informativeText = "Could not retrieve diagnostic information."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Create a scrollable text view to display the diagnostic info
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let textView = NSTextView(frame: scrollView.bounds)
        textView.string = diagnosticInfo
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.textColor
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        
        let alert = NSAlert()
        alert.messageText = "Workspace-Buddy Diagnostic Information"
        alert.informativeText = "This information can help diagnose preset loading and saving issues."
        alert.accessoryView = scrollView
        alert.addButton(withTitle: "Copy to Clipboard")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Copy to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(diagnosticInfo, forType: .string)
            
            let copyAlert = NSAlert()
            copyAlert.messageText = "Copied to Clipboard"
            copyAlert.informativeText = "Diagnostic information has been copied to your clipboard."
            copyAlert.addButton(withTitle: "OK")
            copyAlert.runModal()
        }
    }
    
    /// Show app in dock (called from menu)
    @objc private func showInDock() {
        logger.info("📱 User requested to show app in dock")
        
        NSApp.setActivationPolicy(.regular)
        
        let alert = NSAlert()
        alert.messageText = "App Now Visible in Dock"
        alert.informativeText = "Workspace-Buddy is now visible in your dock. You can drag it to your dock for easy access, or use the menu bar icon as usual."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Monitor startup success and auto-repair if needed
    private func monitorStartupSuccess() {
        logger.info("🔍 Monitoring startup success...")
        
        // Check if we're actually registered for startup
        if !isRegisteredForLogin() {
            logger.warning("⚠️ Startup monitoring detected registration failure - auto-repairing")
            
            // Show user notification
            let notification = NSUserNotification()
            notification.title = "Workspace-Buddy Startup Issue Detected"
            notification.informativeText = "The app will attempt to fix this automatically. You can also check 'Startup Status & Repair' in the menu."
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
            
            // Auto-repair
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.registerForLogin()
            }
        } else {
            logger.info("✅ Startup monitoring confirms registration is working")
        }
        
        // Schedule next check (every 30 minutes)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1800.0) { [weak self] in
            self?.monitorStartupSuccess()
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
            handleStatusButtonClick()
            return
        }
        
        if event.type == .rightMouseUp {
            let menu = createContextMenu()
            let popupPoint = NSPoint(x: 0, y: button.bounds.height - 2)
            menu.popUp(positioning: nil, at: popupPoint, in: button)
        } else {
            handleStatusButtonClick()
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
        
        // Add accessibility permissions status
        let permissionsStatus = hasAccessibilityPermissions() ? "✅ Accessibility Permissions" : "❌ Accessibility Permissions"
        let permissionsHeader = NSMenuItem(title: permissionsStatus, action: nil, keyEquivalent: "")
        permissionsHeader.isEnabled = false
        menu.addItem(permissionsHeader)
        
        if !isRegisteredForLogin() {
            let fixStartupItem = NSMenuItem(title: "Fix Startup Registration", action: #selector(fixStartupRegistration), keyEquivalent: "")
            fixStartupItem.target = self
            menu.addItem(fixStartupItem)
            
            let permissionsItem = NSMenuItem(title: "Request Accessibility Permissions", action: #selector(requestAccessibilityPermissions), keyEquivalent: "")
            permissionsItem.target = self
            menu.addItem(permissionsItem)
            
            let resetPermissionsItem = NSMenuItem(title: "Reset Permission Memory", action: #selector(resetPermissionMemory), keyEquivalent: "")
            resetPermissionsItem.target = self
            menu.addItem(resetPermissionsItem)
            
            let openSystemSettingsItem = NSMenuItem(title: "Open System Settings > Privacy & Security > Accessibility", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            openSystemSettingsItem.target = self
            menu.addItem(openSystemSettingsItem)
            
            let checkMigrationItem = NSMenuItem(title: "Check if Migration Needed", action: #selector(checkPresetMigration), keyEquivalent: "")
            checkMigrationItem.target = self
            menu.addItem(checkMigrationItem)
        } else {
            let removeStartupItem = NSMenuItem(title: "Remove from Startup", action: #selector(removeFromStartup), keyEquivalent: "")
            removeStartupItem.target = self
            menu.addItem(removeStartupItem)
        }
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add "Reset and Migrate Presets" option
        let resetPresetsItem = NSMenuItem(title: "Reset and Migrate Presets", action: #selector(resetAndMigratePresets), keyEquivalent: "")
        resetPresetsItem.target = self
        menu.addItem(resetPresetsItem)
        
        // Add "Force Migrate Current Presets" option
        let forceMigrateItem = NSMenuItem(title: "Force Migrate Current Presets", action: #selector(forceMigrateCurrentPresets), keyEquivalent: "")
        forceMigrateItem.target = self
        menu.addItem(forceMigrateItem)
        
        // Add "Show Diagnostic Info" option
        let diagnosticItem = NSMenuItem(title: "Show Diagnostic Info", action: #selector(showDiagnosticInfo), keyEquivalent: "")
        diagnosticItem.target = self
        menu.addItem(diagnosticItem)
        
        // Add "Startup Status & Repair" option
        let startupStatusItem = NSMenuItem(title: "Startup Status & Repair", action: #selector(showStartupStatusAndRepair), keyEquivalent: "")
        startupStatusItem.target = self
        menu.addItem(startupStatusItem)
        
        // Add "Show in Dock" option
        let showInDockItem = NSMenuItem(title: "Show in Dock", action: #selector(showInDock), keyEquivalent: "")
        showInDockItem.target = self
        menu.addItem(showInDockItem)
        
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
        presetHandler?.forceSavePresets()
        
        // Clean up global event monitor
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        
        // Remove the status item
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        
        // Close the popover if it's open
        popover?.performClose(nil)
    }
    
    /// Clean up any existing log files that might have been created
    private func cleanupExistingLogFiles() {
        logger.info("🧹 Cleaning up any existing log files...")
        
        let logFiles = [
            "/tmp/workspacebuddy.log",
            "/tmp/workspacebuddy.error.log", 
            "/tmp/workspacebuddy-startup.log"
        ]
        
        for logFile in logFiles {
            if FileManager.default.fileExists(atPath: logFile) {
                do {
                    try FileManager.default.removeItem(atPath: logFile)
                    logger.info("✅ Removed log file: \(logFile)")
                } catch {
                    logger.warning("⚠️ Could not remove log file \(logFile): \(error)")
                }
            }
        }
    }
    
    /// Verify and fix LaunchAgent plist files to ensure they don't create log files
    private func verifyAndFixLaunchAgentFiles() {
        logger.info("🔍 Verifying LaunchAgent files for log file creation...")
        
        let bundleID = Bundle.main.bundleIdentifier ?? "com.workspacebuddy.app"
        let plistPaths = [
            "~/Library/LaunchAgents/\(bundleID).plist",
            "~/Library/LaunchAgents/com.workspacebuddy.startupscript.plist"
        ]
        
        for plistPath in plistPaths {
            let expandedPath = (plistPath as NSString).expandingTildeInPath
            
            if FileManager.default.fileExists(atPath: expandedPath) {
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
                    let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
                    
                    if let plist = plist {
                        var needsUpdate = false
                        var updatedPlist = plist
                        
                        // Check for log file paths and remove them
                        if plist["StandardOutPath"] != nil {
                            updatedPlist.removeValue(forKey: "StandardOutPath")
                            needsUpdate = true
                            logger.info("⚠️ Found StandardOutPath in \(plistPath) - removing")
                        }
                        
                        if plist["StandardErrorPath"] != nil {
                            updatedPlist.removeValue(forKey: "StandardErrorPath")
                            needsUpdate = true
                            logger.info("⚠️ Found StandardErrorPath in \(plistPath) - removing")
                        }
                        
                        // Update the plist if needed
                        if needsUpdate {
                            let updatedData = try PropertyListSerialization.data(fromPropertyList: updatedPlist, format: .xml, options: 0)
                            try updatedData.write(to: URL(fileURLWithPath: expandedPath))
                            logger.info("✅ Updated \(plistPath) to remove log file paths")
                        }
                    }
                } catch {
                    logger.warning("⚠️ Could not verify/fix \(plistPath): \(error)")
                }
            }
        }
    }
    
    /// Force preserve existing presets to prevent defaults from overwriting user changes
    private func forcePreserveExistingPresets() {
        logger.info("🔒 Force preserving existing presets to prevent overwrites...")
        
        // Check if we have a presets file
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let presetsFileURL = documentsPath.appendingPathComponent("presets.json")
            
            if FileManager.default.fileExists(atPath: presetsFileURL.path) {
                logger.info("✅ Found existing presets file - ensuring user changes are preserved")
                
                // Force the preset handler to load and preserve existing presets
                presetHandler?.forceMigrateCurrentPresets()
                
                // Mark that we have user-created presets to prevent future overwrites
                let defaults = UserDefaults.standard
                defaults.set(true, forKey: "hasUserCreatedPresets")
                defaults.set(Date(), forKey: "lastPresetSaveDate")
                logger.info("✅ Marked existing presets as user-created to prevent future overwrites")
                
                // Also force a save to ensure nothing is lost
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.presetHandler?.forceSavePresets()
                }
            } else {
                logger.info("📂 No presets file found - nothing to preserve")
            }
        } else {
            logger.warning("⚠️ Could not access documents directory for preset preservation")
        }
    }
    
    /// Check for old format presets and auto-migrate to prevent overwrites
    private func checkAndAutoMigrateOldFormatPresets() {
        logger.info("🔍 Checking for old format presets to prevent overwrites...")
        
        // Check if we have a presets file in old format
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let presetsFileURL = documentsPath.appendingPathComponent("presets.json")
            
            if FileManager.default.fileExists(atPath: presetsFileURL.path) {
                do {
                    let data = try Data(contentsOf: presetsFileURL)
                    
                    // Try to decode as new format
                    do {
                        let _ = try JSONDecoder().decode([Preset].self, from: data)
                        logger.info("✅ Presets file is already in new format, no migration needed")
                        return
                    } catch {
                        logger.warning("⚠️ Detected old format presets file - auto-migrating to prevent overwrites")
                        
                        // Auto-migrate to prevent future overwrites
                        presetHandler?.forceMigrateCurrentPresets()
                        
                        // Show user notification about the migration
                        let notification = NSUserNotification()
                        notification.title = "Presets Migrated Successfully"
                        notification.informativeText = "Your presets have been automatically migrated to prevent them from being overwritten on reboot."
                        notification.soundName = NSUserNotificationDefaultSoundName
                        NSUserNotificationCenter.default.deliver(notification)
                        
                        logger.info("✅ Auto-migration completed successfully")
                    }
                } catch {
                    logger.error("❌ Error reading presets file for format check: \(error)")
                }
            } else {
                logger.info("📂 No presets file found, nothing to migrate")
            }
        } else {
            logger.warning("⚠️ Could not access documents directory for format check")
        }
    }
}
