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
        popover?.behavior = .applicationDefined  // Changed from .transient to prevent auto-closing
        popover?.contentViewController = NSHostingController(rootView: ContentView().environmentObject(PresetHandler()))
        
        // Set the popover delegate to handle window management
        popover?.delegate = self
        
        // Initialize preset handler
        presetHandler = PresetHandler()
        
        // Ensure presets are properly loaded and saved on first launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.presetHandler?.forceResetAndMigrate()
        }
        
        // Monitor startup success and auto-repair if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.monitorStartupSuccess()
        }
        
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
                // Hide dock icon when popover closes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApp.setActivationPolicy(.accessory)
                }
            } else {
                // Show dock icon when popover opens (makes app more discoverable)
                NSApp.setActivationPolicy(.regular)
                
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
        logger.info("🔄 Starting bulletproof startup registration...")
        
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
    
    // MARK: - Bulletproof Startup Registration Methods
    
    /// Register using LaunchAgent (Most Reliable Method)
    private func registerUsingLaunchAgent(appPath: String) throws {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.workspacebuddy.app"
        let loginItemPath = "~/Library/LaunchAgents/\(bundleID).plist"
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTD/PropertyList-1.0.dtd">
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
            <key>WorkingDirectory</key>
            <string>\(appPath)/Contents</string>
            <key>EnvironmentVariables</key>
            <dict>
                <key>PATH</key>
                <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
            </dict>
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
            # Launch the app
            open "\(appPath)"
            echo "$(date): Workspace-Buddy started via startup script" >> /tmp/workspacebuddy-startup.log
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
        open "\(appPath)"
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
        
        // Add "Reset and Migrate Presets" option
        let resetPresetsItem = NSMenuItem(title: "Reset and Migrate Presets", action: #selector(resetAndMigratePresets), keyEquivalent: "")
        resetPresetsItem.target = self
        menu.addItem(resetPresetsItem)
        
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
        presetHandler?.savePresets()
        
        // Remove the status item
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        
        // Close the popover if it's open
        popover?.performClose(nil)
    }
}
