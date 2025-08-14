# Mac Preset Handler

A powerful macOS workspace manager that lets you create custom presets for different contexts (work, school, gaming, relaxation, etc.) and switch between them seamlessly.

## 🚀 What's New

**We now have TWO versions:**

1. **Python Prototype** - Quick concept testing (no Xcode required)
2. **Swift App** - Full native macOS app with menu bar integration

## 📱 Swift App (Recommended)

The native Swift app provides:
- **Menu Bar Integration**: Click the icon in your top menu bar
- **Real App Management**: Actually launches and closes applications
- **Native Performance**: Fast, responsive macOS experience
- **Persistent Storage**: Your presets are saved automatically

### Quick Start (Swift App)

```bash
# Build and run the Swift app
./build_and_run.sh

# Or build manually with Xcode
open MacPresetHandler.xcodeproj
```

## 🐍 Python Prototype

The Python prototype is perfect for:
- **Concept Testing**: See how the interface feels
- **No Dependencies**: Runs on any Mac without additional software
- **Quick Iteration**: Easy to modify and test ideas

### Quick Start (Python Prototype)

```bash
# Run the prototype
./run_prototype.sh

# Or run directly
python3 dev_prototype.py
```

## ✨ Features

- **Custom Presets**: Create and manage workspace presets for different activities
- **App Management**: Automatically open/close applications based on your preset
- **Smart Transitions**: Choose whether to close previous workspace apps or keep them running
- **Top Bar Integration**: Easy access via menu bar icon (Swift app)
- **Hotkeys**: Quick switching between presets
- **Fully Customizable**: Define exactly what apps and settings you need for each context

## 🎯 Use Cases

- **Work Mode**: Open productivity apps, development tools, communication platforms
- **School Mode**: Launch educational software, note-taking apps, research tools
- **Gaming Mode**: Start gaming clients, voice chat, streaming software
- **Relax Mode**: Open entertainment apps, social media, relaxation tools

## 🛠️ Development

### Swift App
- Built with Swift and SwiftUI for native macOS integration
- Menu bar app with popover interface
- Real application launching/closing functionality
- Requires Xcode for development

### Python Prototype
- Built with Python and tkinter
- Demonstrates the concept and user experience
- No additional dependencies required
- Perfect for rapid prototyping

## 📁 Project Structure

```
Mac-Preset-Handler/
├── MacPresetHandler/           # Swift app source code
│   ├── Preset.swift           # Data model
│   ├── PresetHandler.swift    # Core functionality
│   ├── ContentView.swift      # Main UI
│   └── AppDelegate.swift      # App lifecycle
├── dev_prototype.py           # Python prototype
├── build_and_run.sh           # Swift app build script
├── run_prototype.sh           # Python prototype runner
└── README.md                  # This file
```

## 🚀 Getting Started

### For Users
1. **Try the Python prototype first** to see if you like the concept
2. **Build the Swift app** for the full experience
3. **Create your first preset** and start organizing your workspaces!

### For Developers
1. **Fork the repository**
2. **Run the Python prototype** to understand the concept
3. **Open the Swift project** in Xcode
4. **Contribute improvements** and new features

## 📄 License

See [LICENSE](LICENSE) file for details.

## 🤝 Contributing

We welcome contributions! Whether you want to:
- Improve the Python prototype
- Enhance the Swift app
- Add new features
- Fix bugs
- Improve documentation

Check out [DEVELOPMENT.md](DEVELOPMENT.md) for detailed development information.
