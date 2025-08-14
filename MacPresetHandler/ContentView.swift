import SwiftUI

/// Main content view for the Mac Preset Handler app
struct ContentView: View {
    @StateObject private var presetHandler = PresetHandler()
    @State private var showingAddPreset = false
    @State private var selectedPreset: Preset?
    @State private var showingDeleteAlert = false
    @State private var presetToDelete: Preset?
    
    var body: some View {
        VStack(spacing: 16) {
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
        .padding(16)
        .frame(width: 350, height: 500)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showingAddPreset) {
            AddPresetView(presetHandler: presetHandler)
        }
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
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
                                Image(systemName: "rectangle.stack.3d.up")
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
        .padding(.bottom, 8)
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
        .padding(12)
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
                            selectedPreset = preset
                        },
                        onDelete: {
                            presetToDelete = preset
                            showingDeleteAlert = true
                        },
                        presetHandler: presetHandler
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxHeight: 300)
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
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
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
                    .padding(12)
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
                                ForEach(preset.apps, id: \.self) { app in
                                    HStack {
                                        Image(systemName: "app.badge")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                        Text(app)
                                            .font(.caption)
                                            .lineLimit(1)
                                        Spacer()
                                        
                                        Button(action: {
                                            presetHandler.removeAppFromPreset(app, preset: preset)
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
                            }
                        }
                        
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

// MARK: - Add Preset View

struct AddPresetView: View {
    @ObservedObject var presetHandler: PresetHandler
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var appsText = ""
    @State private var closePrevious = true
    @State private var icon = "folder"
    
    private let availableIcons = [
        "folder", "briefcase", "book", "gamecontroller", "heart", 
        "house", "car", "airplane", "leaf", "star"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Preset Details") {
                    TextField("Preset Name", text: $name)
                    TextField("Description", text: $description)
                    
                    Picker("Icon", selection: $icon) {
                        ForEach(availableIcons, id: \.self) { iconName in
                            HStack {
                                Image(systemName: iconName)
                                Text(iconName.capitalized)
                            }
                            .tag(iconName)
                        }
                    }
                }
                
                Section("Applications") {
                    TextField("Apps (comma-separated)", text: $appsText)
                        .placeholder(when: appsText.isEmpty) {
                            Text("e.g., Safari, Mail, Notes")
                                .foregroundColor(.secondary)
                        }
                    
                    Toggle("Close previous apps when switching", isOn: $closePrevious)
                }
                
                Section("Preview") {
                    if !name.isEmpty || !description.isEmpty || !appsText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: icon)
                                    .foregroundColor(.accentColor)
                                Text(name.isEmpty ? "Preset Name" : name)
                                    .font(.headline)
                            }
                            
                            if !description.isEmpty {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if !appsText.isEmpty {
                                let apps = appsText.split(separator: ",").map(String.init)
                                Text("Apps: \(apps.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("Add New Preset")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addPreset()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !appsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func addPreset() {
        let apps = appsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let preset = Preset(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            apps: apps,
            closePrevious: closePrevious,
            icon: icon
        )
        
        presetHandler.addPreset(preset)
        dismiss()
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

// MARK: - Preview

#Preview {
    ContentView()
}
