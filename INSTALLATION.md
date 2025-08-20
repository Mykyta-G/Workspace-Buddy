# 📥 Installation Guide

## 🚀 Quick Install

### **Option 1: Download DMG (Recommended)**
1. **Download** the latest DMG from the [Releases](https://github.com/Mykyta-G/Mac-Preset-Handler/releases) page
2. **Double-click** the DMG file to mount it
3. **Drag** `Workspace-Buddy.app` to your `Applications` folder
4. **Launch** the app from Applications or Spotlight
5. **Grant permissions** when prompted (menu bar access, etc.)

### **Option 2: Build from Source**
If you prefer to build the app yourself:

```bash
# Clone the repository
git clone https://github.com/Mykyta-G/Mac-Preset-Handler.git
cd Mac-Preset-Handler

# Make the build script executable
chmod +x build_release.sh

# Build and create DMG
./build_release.sh
```

## 🔧 System Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Architecture**: Intel (x86_64) or Apple Silicon (arm64)
- **RAM**: 100MB minimum
- **Storage**: 50MB available space

## 📱 First Launch

### **Initial Setup**
1. **Launch** the app from Applications
2. **Look for the icon** in your menu bar (top-right of screen)
3. **Click the icon** to open the preset manager
4. **Create your first preset** or use the default ones

### **Permissions Required**
The app will request these permissions:
- **Menu Bar Access**: To show the preset manager
- **Accessibility**: To manage other applications
- **Full Disk Access**: To find and launch apps

## 🎯 Creating Your First Preset

1. **Click "Add New Preset"** in the app
2. **Name it** (e.g., "Work", "Gaming", "Study")
3. **Add apps** by searching and selecting them
4. **For browsers**, expand the app row to add websites
5. **Save** and switch to your new preset!

## 🌐 Browser Website Setup

### **Adding Websites to Browsers**
1. **Expand a preset** that contains Safari/Chrome
2. **Click on the browser app** (globe icon)
3. **Click "Add"** next to "Websites"
4. **Enter URL** (e.g., `https://github.com`)
5. **Optional**: Add a custom title
6. **Click "Add Website"**

### **Supported Browsers**
- Safari
- Google Chrome
- Firefox
- Microsoft Edge
- Opera
- Brave

## 🔄 Updating the App

### **Automatic Updates**
- The app checks for updates on launch
- You'll be notified when a new version is available
- Download and install the new DMG

### **Manual Updates**
1. **Download** the latest DMG
2. **Replace** the old app in Applications
3. **Launch** the new version

## 🚨 Troubleshooting

### **App Not Appearing in Menu Bar**
- Check **System Preferences > Security & Privacy > Privacy > Menu Bar**
- Ensure "Workspace-Buddy" is checked
- Restart the app

### **Can't Launch Other Apps**
- Go to **System Preferences > Security & Privacy > Privacy > Accessibility**
- Add "Workspace-Buddy" to the list
- Restart the app

### **Websites Not Opening**
- Ensure the browser app is properly configured
- Check that URLs start with `http://` or `https://`
- Verify the browser app is in your Applications folder

### **Presets Not Saving**
- Check **System Preferences > Security & Privacy > Privacy > Full Disk Access**
- Add "Workspace-Buddy" to the list
- Restart the app

## 📞 Getting Help

- **Issues**: Report bugs on [GitHub Issues](https://github.com/Mykyta-G/Mac-Preset-Handler/issues)
- **Discussions**: Join community discussions on [GitHub Discussions](https://github.com/Mykyta-G/Mac-Preset-Handler/discussions)
- **Documentation**: Check the main [README.md](README.md) for detailed information

## 🎉 You're All Set!

Once installed, Workspace Buddy will:
- **Run in the background** (no dock icon)
- **Show in your menu bar** for easy access
- **Remember all your presets** between launches
- **Automatically save** all your changes
- **Work seamlessly** with your existing apps

Enjoy your new productivity workflow! 🚀
