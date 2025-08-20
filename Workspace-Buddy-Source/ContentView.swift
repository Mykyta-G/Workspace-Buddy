import SwiftUI

/// Main content view for the Mac Preset Handler app
struct ContentView: View {
    @StateObject private var presetHandler = PresetHandler()
    @State private var showingAddPreset = false
    @State private var selectedPreset: Preset?
    @State private var showingDeleteAlert = false
    @State private var presetToDelete: Preset?
    
    // New preset form state
    @State private var newPresetName = ""
    @State private var newPresetDescription = ""
    @State private var newPresetApps: Set<String> = []
    @State private var newPresetAppName = ""
    @State private var newPresetSearchResults: [String] = []
    @State private var newPresetClosePrevious = true
    @State private var newPresetIcon = "folder"
    
    // Edit preset state
    @State private var editingPreset: Preset?
    @State private var editPresetName = ""
    @State private var editPresetDescription = ""
    @State private var editPresetApps: Set<String> = []
    @State private var editPresetAppName = ""
    @State private var editPresetSearchResults: [String] = []
    @State private var editPresetClosePrevious = true
    @State private var editPresetIcon = "folder"
    
    // Icon picker state
    @State private var showIconPicker = false
    @FocusState private var isTextFieldFocused: Bool
    
    // Available icons for selection
    private let availableIcons = [
        "folder", "briefcase", "book", "gamecontroller", "heart", 
        "house", "car", "airplane", "leaf", "star", "laptopcomputer",
        "gamecontroller.fill", "heart.fill", "star.fill", "book.fill",
        "paintbrush", "music.note", "globe", "envelope", "calendar"
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            // Compact header
            headerView
            
            // Current preset indicator
            if let current = presetHandler.currentPreset {
                currentPresetIndicator(current)
            }
            
            // Preset list
            presetListView
            
            // Add preset button
            addPresetButton
        }
        .padding(.horizontal, 23)
        .padding(.vertical, 8)
        .frame(minWidth: 400, maxWidth: 400, minHeight: 500, maxHeight: 600)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay {
            if showingAddPreset {
                createPresetOverlay
            }
            if editingPreset != nil {
                editPresetOverlay
            }
            if showIconPicker {
                iconPickerOverlay
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingAddPreset)
        .animation(.easeInOut(duration: 0.3), value: editingPreset != nil)
        .animation(.easeInOut(duration: 0.3), value: showIconPicker)
        .alert("Delete Preset", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let preset = presetToDelete {
                    presetHandler.deletePreset(preset)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let preset = presetToDelete {
                Text("Are you sure you want to delete '\(preset.name)'?")
            }
        }
    }
    
    // MARK: - New Preset Helper Methods
    
    private var isNewPresetValid: Bool {
        !newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !newPresetDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !newPresetApps.isEmpty
    }
    
    private func searchAppsForNewPreset(query: String) {
        let searchQuery = query.lowercased()
        let allApps = getAllInstalledApps()
        
        newPresetSearchResults = allApps.filter { appName in
            appName.lowercased().contains(searchQuery)
        }.sorted()
    }
    
    private func getAllInstalledApps() -> [String] {
        var apps: [String] = []
        
        let systemPaths = [
            "/System/Applications",
            "/Applications",
            "/Applications/Utilities"
        ]
        
        for path in systemPaths {
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: path) {
                for item in contents {
                    if item.hasSuffix(".app") {
                        let appName = String(item.dropLast(4))
                        apps.append(appName)
                    }
                }
            }
        }
        
        return apps.sorted()
    }
    
    private func createNewPreset() {
        let preset = Preset(
            name: newPresetName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: newPresetDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            stringApps: Array(newPresetApps),
            closePrevious: newPresetClosePrevious,
            icon: newPresetIcon
        )
        
        presetHandler.addPreset(preset)
        resetNewPresetForm()
        showingAddPreset = false
    }
    
    private func resetNewPresetForm() {
        newPresetName = ""
        newPresetDescription = ""
        newPresetApps.removeAll()
        newPresetAppName = ""
        newPresetSearchResults.removeAll()
        newPresetClosePrevious = true
        newPresetIcon = "folder"
    }
    
    // MARK: - Edit Preset Helper Methods
    
    private var isEditPresetValid: Bool {
        !editPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !editPresetDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !editPresetApps.isEmpty
    }
    
    private func searchAppsForEditPreset(query: String) {
        let searchQuery = query.lowercased()
        let allApps = getAllInstalledApps()
        
        editPresetSearchResults = allApps.filter { appName in
            appName.lowercased().contains(searchQuery)
        }.sorted()
    }
    
    private func startEditingPreset(_ preset: Preset) {
        editingPreset = preset
        editPresetName = preset.name
        editPresetDescription = preset.description
        editPresetApps = Set(preset.appNames)
        editPresetIcon = preset.icon ?? "folder"
        editPresetClosePrevious = preset.closePrevious
        editPresetAppName = ""
        editPresetSearchResults.removeAll()
    }
    
    private func saveEditedPreset() {
        guard let preset = editingPreset else { return }
        
        var updatedPreset = preset
        updatedPreset.name = editPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedPreset.description = editPresetDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedPreset.apps = editPresetApps.map { AppWithPosition(name: $0) }
        updatedPreset.icon = editPresetIcon
        updatedPreset.closePrevious = editPresetClosePrevious
        
        presetHandler.updatePreset(updatedPreset)
        resetEditPresetForm()
        editingPreset = nil
    }
    
    private func resetEditPresetForm() {
        editPresetName = ""
        editPresetDescription = ""
        editPresetApps.removeAll()
        editPresetIcon = "folder"
        editPresetClosePrevious = true
        editPresetAppName = ""
        editPresetSearchResults.removeAll()
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            // Main app title
            HStack {
                Spacer()
                Text("Workspace Buddy")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.bottom, 16)
                Spacer()
            }
            
            // Preset info section
            HStack {
                Image(systemName: "rectangle.stack")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workspace Presets")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("\(presetHandler.presets.count) presets available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Current Preset Indicator
    
    private func currentPresetIndicator(_ preset: Preset) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Active: \(preset.name)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(preset.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(8)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Preset List View
    
    private var presetListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(presetHandler.presets) { preset in
                    PresetRowView(
                        presetId: preset.id,
                        isCurrent: presetHandler.currentPreset?.id == preset.id,
                        isLoading: presetHandler.isLoading,
                        onSwitch: {
                            Task {
                                await presetHandler.switchToPreset(preset)
                            }
                        },
                        onEdit: {
                            startEditingPreset(preset)
                        },
                        onDelete: {
                            presetToDelete = preset
                            showingDeleteAlert = true
                        },
                        presetHandler: presetHandler
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .slide.combined(with: .opacity)
                    ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: presetHandler.presets)
            .padding(.horizontal, 16)
        }
        .frame(maxHeight: 250)
        .scrollIndicators(.hidden) // Hide scroll indicators to prevent layout shift
    }
    
    // MARK: - Add Preset Button
    
    private var addPresetButton: some View {
        Button(action: {
            showingAddPreset = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add New Preset")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Create Preset Overlay
    
    private var createPresetOverlay: some View {
        VStack(spacing: 0) {
            // Header with icon and title
            VStack(spacing: 16) {
                Button(action: { showIconPicker = true }) {
                    Image(systemName: newPresetIcon)
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                        .overlay(
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle()),
                            alignment: .bottomTrailing
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Create New Preset")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.top, 40)
            .padding(.bottom, 20)
            
            // Form content
            VStack(spacing: 24) {
                // Name and Description
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preset Name")
                            .font(.headline)
                            .fontWeight(.medium)
                        TextField("Enter preset name", text: $newPresetName)
                            .textFieldStyle(.roundedBorder)
                            .focused($isTextFieldFocused)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.headline)
                            .fontWeight(.medium)
                        TextField("What is this preset for?", text: $newPresetDescription)
                            .textFieldStyle(.roundedBorder)
                            .focused($isTextFieldFocused)
                    }
                }
                
                // Apps section (same as existing presets)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Applications")
                            .font(.headline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(newPresetApps.count) apps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Add new app section
                    HStack(spacing: 12) {
                        TextField("Search for app...", text: $newPresetAppName)
                            .focused($isTextFieldFocused)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: newPresetAppName) { _, newValue in
                                if !newValue.isEmpty {
                                    searchAppsForNewPreset(query: newValue)
                                }
                            }
                        
                        Button("Add") {
                            if !newPresetAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                let appName = newPresetAppName.trimmingCharacters(in: .whitespacesAndNewlines)
                                newPresetApps.insert(appName)
                                newPresetAppName = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newPresetAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    // Search results
                    if !newPresetAppName.isEmpty && !newPresetSearchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Found apps:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            ForEach(newPresetSearchResults.prefix(5), id: \.self) { appName in
                                Button(action: {
                                    newPresetApps.insert(appName)
                                    newPresetAppName = ""
                                }) {
                                    HStack {
                                        Image(systemName: "app.badge")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                        Text(appName)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Selected apps
                    if !newPresetApps.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(Array(newPresetApps), id: \.self) { appName in
                                HStack(spacing: 6) {
                                    Image(systemName: "app.badge")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    
                                    Text(appName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    
                                    Button(action: {
                                        newPresetApps.remove(appName)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                
                // Behavior toggle
                Toggle("Close previous apps when switching", isOn: $newPresetClosePrevious)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    resetNewPresetForm()
                    showingAddPreset = false
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Spacer()
                
                Button("Create Preset") {
                    createNewPreset()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isNewPresetValid)
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.15)),
                alignment: .top
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .zIndex(1000)
    }
    
    // MARK: - Icon Picker Overlay
    
    private var iconPickerOverlay: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Text("Choose Icon")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.top, 40)
            .padding(.bottom, 20)
            
            // Icon grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(availableIcons, id: \.self) { iconName in
                        Button(action: { 
                            // Dismiss keyboard focus first
                            isTextFieldFocused = false
                            
                            if editingPreset != nil {
                                editPresetIcon = iconName
                            } else {
                                newPresetIcon = iconName
                            }
                            showIconPicker = false
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: iconName)
                                    .font(.title)
                                    .foregroundColor(iconName == (editingPreset != nil ? editPresetIcon : newPresetIcon) ? .white : .blue)
                                
                                Text(iconName.replacingOccurrences(of: ".fill", with: "").capitalized)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(iconName == (editingPreset != nil ? editPresetIcon : newPresetIcon) ? .white : .secondary)
                                    .lineLimit(1)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background(iconName == (editingPreset != nil ? editPresetIcon : newPresetIcon) ? Color.blue : Color.gray.opacity(0.08))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(iconName == (editingPreset != nil ? editPresetIcon : newPresetIcon) ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }
            
            // Action bar
            HStack {
                Button("Cancel") {
                    // Dismiss keyboard focus first
                    isTextFieldFocused = false
                    showIconPicker = false
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Spacer()
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.15)),
                alignment: .top
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .zIndex(1001)
    }
    
    // MARK: - Edit Preset Overlay
    
    private var editPresetOverlay: some View {
        VStack(spacing: 0) {
            // Header with icon and title
            VStack(spacing: 16) {
                Button(action: { showIconPicker = true }) {
                    Image(systemName: editPresetIcon)
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                        .overlay(
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle()),
                            alignment: .bottomTrailing
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Edit Preset")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.top, 40)
            .padding(.bottom, 20)
            
            // Form content
            VStack(spacing: 24) {
                // Name and Description
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preset Name")
                            .font(.headline)
                            .fontWeight(.medium)
                        TextField("Enter preset name", text: $editPresetName)
                            .textFieldStyle(.roundedBorder)
                            .focused($isTextFieldFocused)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.headline)
                            .fontWeight(.medium)
                        TextField("What is this preset for?", text: $editPresetDescription)
                            .textFieldStyle(.roundedBorder)
                            .focused($isTextFieldFocused)
                    }
                }
                
                // Apps section (same as existing presets)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Applications")
                            .font(.headline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(editPresetApps.count) apps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Add new app section
                    HStack(spacing: 12) {
                        TextField("Search for app...", text: $editPresetAppName)
                            .focused($isTextFieldFocused)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: editPresetAppName) { _, newValue in
                                if !newValue.isEmpty {
                                    searchAppsForEditPreset(query: newValue)
                                }
                            }
                        
                        Button("Add") {
                            if !editPresetAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                let appName = editPresetAppName.trimmingCharacters(in: .whitespacesAndNewlines)
                                editPresetApps.insert(appName)
                                editPresetAppName = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(editPresetAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    // Search results
                    if !editPresetAppName.isEmpty && !editPresetSearchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Found apps:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            ForEach(editPresetSearchResults.prefix(5), id: \.self) { appName in
                                Button(action: {
                                    editPresetApps.insert(appName)
                                    editPresetAppName = ""
                                }) {
                                    HStack {
                                        Image(systemName: "app.badge")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                        Text(appName)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Selected apps
                    if !editPresetApps.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(Array(editPresetApps), id: \.self) { appName in
                                HStack(spacing: 6) {
                                    Image(systemName: "app.badge")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    
                                    Text(appName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    
                                    Button(action: {
                                        editPresetApps.remove(appName)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                
                // Behavior toggle
                Toggle("Close previous apps when switching", isOn: $editPresetClosePrevious)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    resetEditPresetForm()
                    editingPreset = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Spacer()
                
                Button("Save Changes") {
                    saveEditedPreset()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isEditPresetValid)
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.15)),
                alignment: .top
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .zIndex(1000)
    }
}

// MARK: - Preset Row View

struct PresetRowView: View {
    let presetId: UUID // Use ID instead of preset object
    let isCurrent: Bool
    let isLoading: Bool
    let onSwitch: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let presetHandler: PresetHandler
    
    @State private var isExpanded = false
    @State private var newAppName = ""
    @State private var showingAddApp = false
    @State private var searchResults: [String] = []
    @State private var expandedBrowserApps: Set<String> = [] // Track which browser apps are expanded
    
    // Get the current preset data from the handler
    private var preset: Preset? {
        presetHandler.presets.first { $0.id == presetId }
    }
    
    // MARK: - Search Function
    
    private func searchApps(query: String) {
        let searchQuery = query.lowercased()
        let allApps = getAllInstalledApps()
        
        searchResults = allApps.filter { appName in
            appName.lowercased().contains(searchQuery)
        }.sorted()
    }
    
    /// Get the actual icon for an application
    private func getAppIcon(for appName: String) -> NSImage? {
        let appPaths = [
            "/Applications/\(appName).app",
            "/System/Applications/\(appName).app",
            "/Applications/Utilities/\(appName).app"
        ]
        
        for path in appPaths {
            if let bundle = Bundle(path: path) {
                if let iconPath = bundle.path(forResource: "AppIcon", ofType: "icns") {
                    return NSImage(contentsOfFile: iconPath)
                }
                // Try to get the icon from the bundle's info.plist
                if let iconFile = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String {
                    let iconPath = bundle.path(forResource: iconFile, ofType: nil) ?? bundle.path(forResource: iconFile, ofType: "icns")
                    if let iconPath = iconPath {
                        return NSImage(contentsOfFile: iconPath)
                    }
                }
            }
        }
        return nil
    }
    
    /// Get a fallback icon for when the real icon can't be loaded
    private func getFallbackIcon(for appName: String) -> String {
        let lowercasedName = appName.lowercased()
        
        // Browser apps
        if lowercasedName.contains("safari") { return "globe" }
        if lowercasedName.contains("chrome") { return "globe" }
        if lowercasedName.contains("firefox") { return "globe" }
        
        // Development apps
        if lowercasedName.contains("xcode") { return "hammer" }
        if lowercasedName.contains("terminal") { return "terminal" }
        if lowercasedName.contains("code") { return "chevron.left.forwardslash.chevron.right" }
        
        // Communication apps
        if lowercasedName.contains("slack") { return "message" }
        if lowercasedName.contains("discord") { return "gamecontroller" }
        if lowercasedName.contains("teams") { return "person.2" }
        
        // Media apps
        if lowercasedName.contains("spotify") { return "music.note" }
        if lowercasedName.contains("music") { return "music.note" }
        if lowercasedName.contains("photos") { return "photo" }
        if lowercasedName.contains("tv") { return "tv" }
        
        // Productivity apps
        if lowercasedName.contains("mail") { return "envelope" }
        if lowercasedName.contains("notes") { return "note.text" }
        if lowercasedName.contains("calendar") { return "calendar" }
        if lowercasedName.contains("pages") { return "doc.text" }
        if lowercasedName.contains("keynote") { return "presentation" }
        if lowercasedName.contains("numbers") { return "tablecells" }
        
        // Gaming apps
        if lowercasedName.contains("steam") { return "gamecontroller" }
        
        // Default fallback
        return "app.badge"
    }
    
    private func getAllInstalledApps() -> [String] {
        var apps: [String] = []
        
        // System Applications
        let systemPaths = [
            "/System/Applications",
            "/Applications",
            "/Applications/Utilities"
        ]
        
        for path in systemPaths {
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: path) {
                for item in contents {
                    if item.hasSuffix(".app") {
                        let appName = String(item.dropLast(4)) // Remove .app extension
                        apps.append(appName)
                    }
                }
            }
        }
        
        return apps.sorted()
    }
    
    var body: some View {
        if let preset = preset {
            VStack(spacing: 0) {
                // Main preset row - now clickable to expand/collapse
                Button(action: { 
                    isExpanded.toggle()
                    if !isExpanded {
                        // Clear search when closing
                        newAppName = ""
                        searchResults = []
                    }
                }) {
                    HStack(spacing: 12) {
                        // Icon and preset info
                        HStack(spacing: 8) {
                            Image(systemName: preset.icon ?? "folder")
                                .foregroundColor(isCurrent ? .green : .blue)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(isCurrent ? .primary : .secondary)
                                
                                Text(preset.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        // Status indicator
                        if isCurrent {
                            Text("ACTIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                        
                        // Action buttons
                        HStack(spacing: 6) {
                            // Chevron indicator (no longer a button, just visual)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.body)
                                .foregroundColor(.blue)
                                .frame(width: 24, height: 24)
                            
                            Button(action: onEdit) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(.blue)
                            
                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(.red)
                            
                            Button(isCurrent ? "Current" : "Switch") {
                                onSwitch()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(isCurrent || isLoading)
                            
                            if isLoading && isCurrent {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Expandable apps section
                if isExpanded {
                    VStack(spacing: 12) {
                        // Apps list
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Applications")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(preset.apps.count) apps")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Apps list with remove buttons
                            VStack(spacing: 6) {
                                ForEach(preset.apps, id: \.name) { app in
                                    VStack(spacing: 0) {
                                        // App row - make entire browser row clickable for expansion
                                        if app.isBrowser {
                                            Button(action: {
                                                if expandedBrowserApps.contains(app.name) {
                                                    expandedBrowserApps.remove(app.name)
                                                } else {
                                                    expandedBrowserApps.insert(app.name)
                                                }
                                            }) {
                                                HStack(spacing: 8) {
                                                    // Collapse indicator for browser apps
                                                    Image(systemName: expandedBrowserApps.contains(app.name) ? "chevron.down" : "chevron.right")
                                                        .font(.caption2)
                                                        .foregroundColor(.blue)
                                                        .frame(width: 16, height: 16)
                                                    
                                                    // App icon - try to get real icon, fallback to system icon
                                                    if let appIcon = getAppIcon(for: app.name) {
                                                        Image(nsImage: appIcon)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(width: 16, height: 16)
                                                    } else {
                                                        Image(systemName: getFallbackIcon(for: app.name))
                                                            .font(.caption2)
                                                            .foregroundColor(.green)
                                                    }
                                                    
                                                    VStack(alignment: .leading, spacing: 1) {
                                                        Text(app.name)
                                                            .font(.caption)
                                                            .lineLimit(1)
                                                        
                                                        // Show website count for browser apps
                                                        let websiteCount = app.websites.count
                                                        Text(websiteCount == 0 ? "No websites" : "\(websiteCount) website\(websiteCount == 1 ? "" : "s")")
                                                            .font(.caption2)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Button(action: {
                                                        presetHandler.removeAppFromPreset(app.name, preset: preset)
                                                    }) {
                                                        Image(systemName: "trash")
                                                            .font(.caption2)
                                                            .foregroundColor(.red)
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 6)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(6)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        } else {
                                            // Non-browser apps - regular row
                                            HStack(spacing: 8) {
                                                // Spacer for alignment
                                                Color.clear
                                                    .frame(width: 16, height: 16)
                                                
                                                // App icon - try to get real icon, fallback to system icon
                                                if let appIcon = getAppIcon(for: app.name) {
                                                    Image(nsImage: appIcon)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 16, height: 16)
                                                } else {
                                                    Image(systemName: getFallbackIcon(for: app.name))
                                                        .font(.caption2)
                                                        .foregroundColor(.blue)
                                                }
                                                
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(app.name)
                                                        .font(.caption)
                                                        .lineLimit(1)
                                                }
                                                
                                                Spacer()
                                                
                                                Button(action: {
                                                    presetHandler.removeAppFromPreset(app.name, preset: preset)
                                                }) {
                                                    Image(systemName: "trash")
                                                        .font(.caption2)
                                                        .foregroundColor(.red)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(6)
                                        }
                                        
                                        // Show website management for browser apps only when expanded
                                        if app.isBrowser && expandedBrowserApps.contains(app.name) {
                                            WebsiteManagementView(
                                                presetHandler: presetHandler,
                                                preset: preset,
                                                appName: app.name
                                            )
                                            .padding(.leading, 24) // Indent under the app
                                            .transition(.asymmetric(
                                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                                removal: .scale(scale: 0.95).combined(with: .opacity)
                                            ))
                                        }
                                    }
                                }
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: expandedBrowserApps)
                        
                        // Add new app section with smooth search
                        VStack(spacing: 8) {
                            HStack {
                                TextField("Search for app...", text: $newAppName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.caption)
                                    .onChange(of: newAppName) { _, newValue in
                                        // Trigger search as user types
                                        if !newValue.isEmpty {
                                            searchApps(query: newValue)
                                        }
                                    }
                                
                                Button("Add") {
                                    if !newAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        let appName = newAppName.trimmingCharacters(in: .whitespacesAndNewlines)
                                        presetHandler.addAppToPreset(appName, preset: preset)
                                        newAppName = ""
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(newAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            
                            // Search results
                            if !newAppName.isEmpty && !searchResults.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Found apps:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    ForEach(searchResults.prefix(5), id: \.self) { appName in
                                        Button(action: {
                                            print("Adding app: \(appName) to preset: \(preset.name)")
                                            presetHandler.addAppToPreset(appName, preset: preset)
                                            newAppName = ""
                                            searchResults = []
                                        }) {
                                            HStack {
                                                Image(systemName: "app.badge")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                                Text(appName)
                                                    .font(.caption)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .cornerRadius(8)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
        } else {
            // Fallback if preset not found
            Text("Preset not found")
                .foregroundColor(.red)
        }
    }
}



// MARK: - Extensions

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Website Management View

struct WebsiteManagementView: View {
    @ObservedObject var presetHandler: PresetHandler
    let preset: Preset
    let appName: String
    
    @State private var newWebsiteURL = ""
    @State private var newWebsiteTitle = ""
    @State private var isAddingWebsite = false
    
    private var app: AppWithPosition? {
        preset.apps.first { $0.name == appName }
    }
    
    private var websites: [BrowserWebsite] {
        app?.websites ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with add button
            HStack {
                Text("Websites")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { isAddingWebsite.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isAddingWebsite ? "minus.circle.fill" : "plus.circle.fill")
                            .font(.caption)
                        Text(isAddingWebsite ? "Cancel" : "Add")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 4)
            
            // Inline website input
            if isAddingWebsite {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("https://example.com", text: $newWebsiteURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.caption)
                        
                        TextField("Title (optional)", text: $newWebsiteTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.caption)
                            .frame(width: 100)
                    }
                    
                    Button("Add Website") {
                        addWebsite()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(newWebsiteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(10)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(8)
            }
            
            // Existing websites list
            if websites.isEmpty && !isAddingWebsite {
                Text("No websites configured")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.vertical, 4)
            } else if !websites.isEmpty {
                VStack(spacing: 6) {
                    ForEach(websites) { website in
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .frame(width: 16)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(website.displayTitle)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                Text(website.url)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                presetHandler.removeWebsiteFromApp(website, appName: appName, preset: preset)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.08))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    private func addWebsite() {
        let trimmedURL = newWebsiteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = newWebsiteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedURL.isEmpty {
            let website = BrowserWebsite(url: trimmedURL, title: trimmedTitle)
            presetHandler.addWebsiteToApp(website, appName: appName, preset: preset)
            cancelAdding()
        }
    }
    
    private func cancelAdding() {
        newWebsiteURL = ""
        newWebsiteTitle = ""
        isAddingWebsite = false
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}


