# Workspace-Buddy 🚀

A powerful macOS menu bar application for managing workspace presets and applications. Create custom workspaces, switch between them seamlessly, and maintain your productivity workflow.

## ✨ Features

- **Custom Presets**: Create unlimited workspace presets (Work, Gaming, Study, etc.)
- **App Management**: Assign multiple applications to each preset
- **One-Click Switching**: Switch between workspaces instantly
- **Browser Integration**: Automatically open specific websites when switching to browser presets
- **Smart App Handling**: Automatically close previous apps when switching (optional)
- **Menu Bar Integration**: Clean, accessible interface from the top menu bar

## 📥 Installation

### Quick Install (Recommended)
1. Download `Workspace-Buddy-v1.0.dmg`
2. Double-click to mount the disk image
3. Drag Workspace-Buddy to your Applications folder
4. Launch the app and access from the menu bar

### Manual Build
```bash
git clone https://github.com/Mykyta-G/Mac-Preset-Handler.git
cd Mac-Preset-Handler
./build.sh
```

## 🎯 Quick Start

1. **Launch the app** - Look for the list icon in your menu bar
2. **Create a preset** - Click the + button to add a new workspace
3. **Add apps** - Search and select applications for your preset
4. **Add websites** (optional) - For browser apps, expand the row to add URLs
5. **Switch presets** - Click any preset to instantly switch to that workspace

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

## 🔒 Security & Permissions

If you encounter security warnings:
1. Right-click on Workspace-Buddy in Applications
2. Select "Open" from the context menu
3. Click "Open" in the security dialog

The app will work normally after this. This happens because macOS protects users from self-built apps.

## 🛠️ Development

### Project Structure
```
Workspace-Buddy/
├── Workspace-BuddyApp.swift    # Main app entry point
├── ContentView.swift            # Main UI and preset management
├── Preset.swift                 # Preset data model
├── PresetHandler.swift          # Business logic and app management
└── Assets.xcassets/            # App icons and resources
```

### Building
```bash
# Build and launch (development)
./build.sh

# Create release DMG
./build_release.sh
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and test thoroughly
4. Submit a Pull Request

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 📞 Support

- **Issues**: Report bugs on GitHub
- **Documentation**: Check `DEVELOPMENT.md` for detailed guides
- **Installation**: Download the latest DMG from releases

---

**Transform your Mac into a productivity powerhouse with intelligent workspace management!**
