# Workspace-Buddy 🚀

A powerful macOS menu bar application for managing workspace presets and applications. Create custom workspaces, switch between them seamlessly, and maintain your productivity workflow.

## 🔒 Security & Permissions

### ⚠️ Important: First Launch Setup

Since this app is not code-signed with an Apple Developer certificate, macOS will block it by default. Here's how to enable it:

1. Go to **System Preferences** → **Security & Privacy** → **General**
2. Look for a message about Workspace-Buddy being blocked
3. Click **"Open Anyway"** next to the message
4. Launch the app normally

### Required Permissions
The app will request these permissions on first launch:
- **Menu Bar Access**: To display the preset manager in your menu bar
- **Accessibility**: To manage and launch other applications
- **Full Disk Access**: To discover installed applications

Grant these permissions when prompted for full functionality.

### Why This Happens
This is normal behavior for apps without an Apple Developer certificate. macOS protects users by blocking unsigned applications, but you can safely allow this app to run.

## ✨ Features

- **Custom Presets**: Create unlimited workspace presets (Work, Gaming, Study, etc.)
- **App Management**: Assign multiple applications to each preset
- **One-Click Switching**: Switch between workspaces instantly
- **Browser Integration**: Automatically open specific websites when switching to browser presets
- **Smart App Handling**: Automatically close previous apps when switching (optional)
- **Menu Bar Integration**: Clean, accessible interface from the top menu bar

## 📥 Installation

### Quick Install (Recommended)
1. **Download** `Workspace-Buddy-v1.0.dmg` from the [Releases](https://github.com/Mykyta-G/Mac-Preset-Handler/releases) page
2. **Double-click** the DMG file to mount it
3. **Drag** `Workspace-Buddy.app` to your `Applications` folder
4. **Launch** the app (see [Security & Permissions](#-security--permissions) for first-time setup)
5. **Look for the icon** in your menu bar (top-right of screen)

### Build from Source
```bash
# Clone the repository
git clone https://github.com/Mykyta-G/Mac-Preset-Handler.git
cd Mac-Preset-Handler

# Build the app
./build_workspace_buddy.sh
```

## 🎯 Quick Start

### First Time Setup
1. **Launch the app** - Look for the list icon in your menu bar (top-right)
2. **Grant permissions** when prompted (menu bar access, accessibility, etc.)
3. **Explore default presets** - Work, School, Gaming, and Relax are pre-configured

### Creating Your First Custom Preset
1. **Click the "+" button** to add a new workspace preset
2. **Name your preset** (e.g., "Development", "Design", "Study")
3. **Add applications** - Use the search bar to find and select apps
4. **Add websites** (optional) - For browser apps, expand the row to add URLs
5. **Save and switch** - Click your new preset to instantly switch to that workspace

### Using Presets
- **Switch workspaces** - Click any preset name to activate it
- **View details** - Click the arrow to expand and see all assigned apps
- **Edit presets** - Modify apps and websites anytime
- **Delete presets** - Remove unwanted configurations

## 🔧 System Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Architecture**: Intel & Apple Silicon (Universal Binary)
- **Storage**: ~50MB
- **Permissions**: Menu bar access (granted automatically)

## 🎨 How It Works

### Preset Management
- **Create unlimited presets** with custom names and descriptions
- **Assign multiple apps** to each preset using real-time search
- **Automatic saving** - all changes persist between sessions

### App Discovery
- **Real-time search** through all installed applications
- **Smart detection** of apps in System, Applications, and Utilities folders
- **App name normalization** - type "google" → finds "Google Chrome"

### Browser Integration
- **Website management** for browser apps (Safari, Chrome, Firefox, etc.)
- **Automatic URL opening** when switching to browser presets
- **URL validation** and auto-title detection

### Workspace Switching
- **Instant switching** between different workspace configurations
- **Smart app handling** - optionally close previous apps
- **Smooth transitions** with expandable preset rows

## 🚀 Use Cases

### Work Environment
- **Development**: Xcode, Terminal, Safari (GitHub, Stack Overflow), Slack
- **Design**: Figma, Photoshop, Browser (design resources)
- **Office**: Word, Excel, Teams, Calendar

### Gaming Setup
- **Gaming**: Steam, Discord, Game clients
- **Streaming**: OBS, Twitch, YouTube
- **Communication**: Discord, Teamspeak

### Study Mode
- **Research**: Safari (Canvas, Google Drive), Notes, Calendar
- **Documentation**: Word, PDF readers, Reference apps

## 🛠️ Development

### Project Structure
```
Workspace-Buddy/
├── Workspace-Buddy-Source/
│   ├── Workspace-BuddyApp.swift    # Main app entry point
│   ├── ContentView.swift            # Main UI and preset management
│   ├── Preset.swift                 # Preset data model
│   ├── PresetHandler.swift          # Business logic and app management
│   └── Assets.xcassets/            # App icons and resources
├── build_workspace_buddy.sh         # Build script
└── Package.swift                    # Swift Package Manager configuration
```

### Building
```bash
# Development build
./build_workspace_buddy.sh

# Create release DMG
./build_workspace_buddy.sh --release
```

### Documentation
- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Detailed development guide
- **[INSTALLATION.md](INSTALLATION.md)** - Comprehensive installation instructions

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and test thoroughly
4. Submit a Pull Request

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 📞 Support & Resources

### Getting Help
- **🐛 Bug Reports**: [GitHub Issues](https://github.com/Mykyta-G/Mac-Preset-Handler/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/Mykyta-G/Mac-Preset-Handler/discussions)
- **📖 Documentation**: 
  - [Installation Guide](INSTALLATION.md) - Detailed setup instructions
  - [Development Guide](DEVELOPMENT.md) - For contributors and developers

### Downloads
- **📦 Latest Release**: [Download DMG](https://github.com/Mykyta-G/Mac-Preset-Handler/releases)
- **🔧 Source Code**: Clone the repository to build from source

---

**Transform your Mac into a productivity powerhouse with intelligent workspace management!**
