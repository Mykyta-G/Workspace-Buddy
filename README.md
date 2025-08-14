# Mac Preset Handler 🚀

A powerful macOS menu bar application for managing workspace presets and applications. Create custom workspaces with specific apps, switch between them seamlessly, and maintain your productivity workflow.

## ✨ Features

### 🎯 **Smart Workspace Management**
- **Custom Presets**: Create unlimited workspace presets (Work, School, Gaming, Relax, etc.)
- **App Bundles**: Assign multiple applications to each preset
- **One-Click Switching**: Switch between workspaces instantly
- **Smart App Handling**: Automatically close previous apps when switching (optional)

### 🔍 **Intelligent App Search & Management**
- **Real-Time Search**: Search all installed applications as you type
- **Smart App Detection**: Automatically finds apps in System, Applications, and Utilities folders
- **App Name Normalization**: Type "google" → becomes "Google Chrome"
- **Instant App Addition**: Click any search result to add to preset
- **Easy App Removal**: Red trash icons for each app in presets

### 🎨 **Modern, Intuitive Interface**
- **Menu Bar Integration**: Clean, accessible from the top menu bar
- **Expandable Presets**: Click any preset row to expand and manage apps
- **Smooth Animations**: Beautiful expand/collapse transitions
- **Compact Design**: Efficient use of space with clean layouts
- **Visual Feedback**: Clear indicators for active presets and loading states

### 🚀 **Advanced Functionality**
- **Automatic Saving**: Presets are automatically saved and persist between sessions
- **System Integration**: Seamlessly works with macOS applications
- **Performance Optimized**: Lightweight and fast operation
- **Developer Friendly**: Built with SwiftUI and modern macOS APIs

## 🎯 Use Cases

### 💼 **Work Environment**
- **Development**: Xcode, Terminal, Safari, Slack, Mail
- **Design**: Figma, Photoshop, Sketch, Browser
- **Office**: Word, Excel, PowerPoint, Teams, Calendar

### 🎮 **Gaming Setup**
- **Gaming Apps**: Steam, Discord, Game clients
- **Streaming**: OBS, Twitch, YouTube
- **Communication**: Discord, Teamspeak, Mumble

### 📚 **Study Mode**
- **Research**: Safari, Notes, Calendar, Mail
- **Documentation**: Word, PDF readers, Reference apps
- **Focus**: Music apps, Timer apps, Study tools

### 🏠 **Personal/Relax**
- **Entertainment**: Netflix, Spotify, Games
- **Social**: Social media apps, Messaging
- **Hobbies**: Photo editing, Music creation, Reading

## 🛠️ Installation & Setup

### Prerequisites
- macOS 14.0 or later
- Xcode 15.0+ (for development)
- Swift 6.0+

### Quick Start
1. **Clone the repository**
   ```bash
   git clone https://github.com/Mykyta-G/Mac-Preset-Handler.git
   cd Mac-Preset-Handler
   ```

2. **Build and run**
   ```bash
   ./build.sh
   ```

3. **Access from menu bar**
   - Look for the list icon in your top menu bar
   - Click to open the preset manager
   - Start creating your workspaces!

## 🔧 Development

### Project Structure
```
MacPresetHandler/
├── MacPresetHandler/
│   ├── MacPresetHandlerApp.swift    # Main app entry point
│   ├── ContentView.swift            # Main UI and preset management
│   ├── Preset.swift                 # Preset data model
│   ├── PresetHandler.swift          # Business logic and app management
│   └── Assets.xcassets/            # App icons and resources
├── Package.swift                    # Swift Package Manager configuration
├── build.sh                         # Build and launch script
└── presets.json                     # User preset storage
```

### Key Components

#### **Preset Model** (`Preset.swift`)
- `id`: Unique identifier for each preset
- `name`: Human-readable preset name
- `description`: Optional description
- `icon`: SF Symbol name for visual representation
- `apps`: Array of application names
- `closePrevious`: Whether to close previous apps when switching

#### **Preset Handler** (`PresetHandler.swift`)
- **Preset Management**: CRUD operations for presets
- **App Management**: Add/remove apps from presets
- **Workspace Switching**: Launch and close applications
- **Data Persistence**: Automatic saving to JSON
- **Smart App Detection**: Find apps in system directories

#### **Content View** (`ContentView.swift`)
- **Preset List**: Display and manage all presets
- **Expandable Rows**: Click to expand and manage apps
- **Smart Search**: Real-time app search and discovery
- **Modern UI**: Clean, responsive interface

### Building the Project

#### **Using Swift Package Manager**
```bash
# Clean build
swift package clean

# Build for release
swift build -c release

# Run tests
swift test
```

#### **Using the Build Script**
```bash
# Build and launch
./build.sh

# Clean and rebuild
rm -rf .build && ./build.sh
```

## 🎨 UI/UX Features

### **Expandable Preset Rows**
- **Click anywhere** on a preset row to expand/collapse
- **Smooth animations** with easing effects
- **Visual feedback** with chevron indicators
- **Large click targets** for better usability

### **Smart App Search**
- **Real-time results** as you type
- **Comprehensive coverage** of all installed apps
- **Smart filtering** and sorting
- **Instant app addition** from search results

### **Modern Design Elements**
- **System-native colors** and styling
- **Consistent spacing** and typography
- **Responsive layouts** that adapt to content
- **Accessibility features** for all users

## 🔍 How It Works

### **App Discovery**
1. **System Scan**: Automatically scans `/System/Applications`, `/Applications`, and `/Applications/Utilities`
2. **Real-time Search**: Filters apps as you type in the search field
3. **Smart Matching**: Finds apps by partial names and common aliases

### **Preset Management**
1. **Create Presets**: Add new workspace configurations
2. **Assign Apps**: Search and add applications to each preset
3. **Switch Workspaces**: One-click switching between different setups
4. **Automatic Saving**: All changes are persisted automatically

### **Application Launching**
1. **Path Detection**: Finds apps in standard macOS locations
2. **Smart Fallbacks**: Handles both system and third-party applications
3. **Error Handling**: Graceful fallbacks when apps can't be launched

## 🚀 Future Enhancements

### **Planned Features**
- **App Icons**: Display actual app icons instead of generic symbols
- **Preset Templates**: Pre-built templates for common workflows
- **Keyboard Shortcuts**: Global hotkeys for quick preset switching
- **Cloud Sync**: Sync presets across multiple devices
- **Advanced Scheduling**: Auto-switch presets based on time or location

### **Performance Improvements**
- **Lazy Loading**: Load app lists on demand
- **Background Updates**: Update app availability in background
- **Caching**: Smart caching for frequently accessed data

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### **Development Setup**
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and test thoroughly
4. Commit your changes: `git commit -m 'Add amazing feature'`
5. Push to the branch: `git push origin feature/amazing-feature`
6. Open a Pull Request

### **Areas for Contribution**
- **UI/UX Improvements**: Better designs and user experience
- **App Compatibility**: Support for more applications
- **Performance**: Faster app detection and switching
- **Documentation**: Better guides and examples
- **Testing**: More comprehensive test coverage

### **Code Style**
- Follow Swift style guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Include error handling for edge cases

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **macOS Development Community** for inspiration and guidance
- **SwiftUI Team** for the amazing framework
- **SF Symbols** for the beautiful icon system
- **Open Source Contributors** who make projects like this possible

## 📞 Support

### **Getting Help**
- **Issues**: Report bugs or request features on GitHub
- **Discussions**: Join community discussions
- **Documentation**: Check the development guide in `DEVELOPMENT.md`

### **Common Issues**
- **App not appearing**: Check if the app is in `/Applications` or `/System/Applications`
- **Build errors**: Ensure you have the latest Xcode and macOS
- **Menu bar not showing**: Check system permissions for menu bar apps

---

**Made with ❤️ for macOS users who love productivity and organization!**

*Transform your Mac into a productivity powerhouse with intelligent workspace management.*
