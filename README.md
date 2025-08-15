# Mac Preset Handler 🚀

A powerful macOS menu bar application for managing workspace presets and applications. Create custom workspaces with specific apps, switch between them seamlessly, and maintain your productivity workflow with intelligent browser website management.

## ✨ Features

### 🎯 **Smart Workspace Management**
- **Custom Presets**: Create unlimited workspace presets (Work, School, Gaming, Relax, etc.)
- **App Bundles**: Assign multiple applications to each preset
- **One-Click Switching**: Switch between workspaces instantly
- **Smart App Handling**: Automatically close previous apps when switching (optional)

### 🌐 **Advanced Browser Integration**
- **Website Management**: Add specific URLs to open when switching to browser presets
- **Smart URL Handling**: Automatically opens configured websites in Safari, Chrome, Firefox, etc.
- **Collapsible Browser Apps**: Click anywhere on browser rows to expand and manage websites
- **URL Validation**: Ensures only valid URLs are added to presets
- **Auto-Title Detection**: Automatically extracts website titles from URLs

### 🔍 **Intelligent App Search & Management**
- **Real-Time Search**: Search all installed applications as you type
- **Smart App Detection**: Automatically finds apps in System, Applications, and Utilities folders
- **App Name Normalization**: Type "google" → becomes "Google Chrome"
- **Instant App Addition**: Click any search result to add to preset
- **Easy App Removal**: Red trash icons for each app in presets

### 🎨 **Modern, Intuitive Interface**
- **Menu Bar Integration**: Clean, accessible from the top menu bar
- **Expandable Presets**: Click any preset row to expand and manage apps
- **Real App Icons**: Displays actual application icons instead of generic symbols
- **Smooth Animations**: Beautiful expand/collapse transitions
- **Compact Design**: Efficient use of space with clean layouts
- **Visual Feedback**: Clear indicators for active presets and loading states

### 🚀 **Advanced Functionality**
- **Automatic Saving**: Presets are automatically saved and persist between sessions
- **System Integration**: Seamlessly works with macOS applications
- **Performance Optimized**: Lightweight and fast operation
- **Developer Friendly**: Built with SwiftUI and modern macOS APIs
- **Comprehensive Auto-Save**: Saves on app quit, system sleep, shutdown, and every change

## 🎯 Use Cases

### 💼 **Work Environment**
- **Development**: Xcode, Terminal, Safari (with GitHub, Stack Overflow), Slack, Mail
- **Design**: Figma, Photoshop, Sketch, Browser (with design resources)
- **Office**: Word, Excel, PowerPoint, Teams, Calendar

### 🎮 **Gaming Setup**
- **Gaming Apps**: Steam, Discord, Game clients
- **Streaming**: OBS, Twitch, YouTube
- **Communication**: Discord, Teamspeak, Mumble
- **Browser**: Safari/Chrome (with gaming forums, Reddit, Twitch)

### 📚 **Study Mode**
- **Research**: Safari (with Canvas, Google Drive, research sites), Notes, Calendar, Mail
- **Documentation**: Word, PDF readers, Reference apps
- **Focus**: Music apps, Timer apps, Study tools

### 🏠 **Personal/Relax**
- **Entertainment**: Netflix, Spotify, Games
- **Social**: Social media apps, Messaging
- **Hobbies**: Photo editing, Music creation, Reading
- **Browser**: Safari/Chrome (with YouTube, Netflix, Instagram)

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

## 🌐 Website Management

### **How It Works**
The Mac Preset Handler now includes intelligent browser website management that automatically opens specific URLs when you switch to presets containing browser applications.

### **Setting Up Websites**
1. **Expand a Preset**: Click on any preset row to expand it
2. **Find Browser Apps**: Look for apps with globe icons (🌐) - these are browser apps
3. **Click to Expand**: Click anywhere on the browser app row to expand website management
4. **Add Websites**: Use the inline form to add URLs and optional titles
5. **Auto-Open**: When you switch to the preset, all configured websites will automatically open

### **Supported Browsers**
- **Safari** - Native macOS browser
- **Google Chrome** - Popular cross-platform browser
- **Firefox** - Privacy-focused browser
- **Microsoft Edge** - Modern Chromium-based browser
- **Opera** - Feature-rich browser
- **Brave** - Privacy-focused Chromium browser

### **URL Features**
- **Automatic Validation**: Ensures URLs are properly formatted (http/https)
- **Smart Titles**: Automatically extracts website names from URLs
- **Custom Titles**: Option to set your own descriptive names
- **Easy Management**: Add, edit, and remove websites with simple controls

### **Example Workflow**
1. **Create Work Preset** with Safari, Xcode, Terminal
2. **Add Websites** to Safari: GitHub, Stack Overflow, Documentation
3. **Switch to Work Preset** → Safari opens with all your work sites
4. **Switch to Gaming Preset** → Different websites open automatically

## 🚀 Future Enhancements

### **Recently Implemented** ✅
- **Real App Icons**: Now displays actual application icons instead of generic symbols
- **Website Management**: Full browser integration with automatic URL opening
- **Collapsible Browser Apps**: Entire browser rows are clickable for expansion
- **Enhanced Auto-Save**: Comprehensive saving on all app lifecycle events
- **Improved UI/UX**: Cleaner interface with better spacing and visual hierarchy

### **Planned Features**
- **Preset Templates**: Pre-built templates for common workflows
- **Keyboard Shortcuts**: Global hotkeys for quick preset switching
- **Cloud Sync**: Sync presets across multiple devices
- **Advanced Scheduling**: Auto-switch presets based on time or location
- **Website Categories**: Organize websites into groups within browser apps
- **Custom Browser Commands**: Support for browser-specific launch options

### **Performance Improvements**
- **Lazy Loading**: Load app lists on demand
- **Background Updates**: Update app availability in background
- **Caching**: Smart caching for frequently accessed data
- **Icon Caching**: Cache app icons for faster loading

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
