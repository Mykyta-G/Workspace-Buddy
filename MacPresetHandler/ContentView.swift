import SwiftUI

/// Main content view for the Mac Preset Handler app
struct ContentView: View {
    @StateObject private var presetHandler = PresetHandler()
    @State private var showingAddPreset = false
    @State private var selectedPreset: Preset?
    @State private var showingDeleteAlert = false
    @State private var presetToDelete: Preset?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Preset list
            presetListView
            
            // Current preset info
            currentPresetView
            
            // Action buttons
            actionButtonsView
        }
        .frame(width: 600, height: 800)
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
                Text("Are you sure you want to delete '\(preset.name)'? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.3d.up.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            
            Text("Workspace Presets")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Switch between different workspace configurations")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Add Preset") {
                showingAddPreset = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Preset List View
    
    private var presetListView: some View {
        List {
            ForEach(presetHandler.presets) { preset in
                PresetRowView(
                    preset: preset,
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
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Current Preset View
    
    private var currentPresetView: some View {
        Group {
            if let current = presetHandler.currentPreset {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Current Workspace: \(current.name)")
                            .font(.headline)
                    }
                    
                    Text(current.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Apps: \(current.appListText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Action Buttons View
    
    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            Button("Refresh All") {
                // Refresh presets from storage
                presetHandler.refreshPresets()
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("Settings") {
                // TODO: Show settings
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Preset Row View

struct PresetRowView: View {
    let preset: Preset
    let isCurrent: Bool
    let isLoading: Bool
    let onSwitch: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            // Icon and info
            HStack(spacing: 12) {
                Image(systemName: preset.icon ?? "folder")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(preset.name)
                            .font(.headline)
                        
                        if isCurrent {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                    
                    Text(preset.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Text("\(preset.appCount) apps • Close previous: \(preset.closePrevious ? "Yes" : "No")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button("Edit") {
                    onEdit()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Delete") {
                    onDelete()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
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
        .padding(.vertical, 8)
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
