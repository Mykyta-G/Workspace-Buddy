#!/bin/bash

# Mac Preset Handler - Simple Build Script
# This script builds the app with Swift Package Manager

echo "🚀 Building Mac Preset Handler..."
echo "=================================="

# Check if Swift is available
if command -v swift &> /dev/null; then
    echo "✅ Swift found: $(swift --version | head -n 1)"
else
    echo "❌ Swift not found. Please install Xcode or Swift."
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf .build
echo "✅ Cleaned"

# Build the package
echo "🔨 Building package..."
swift build -c release

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    
    # Create app bundle
    echo "📱 Creating app bundle..."
    
    # Create app directory structure
    mkdir -p MacPresetHandler.app/Contents/MacOS
    mkdir -p MacPresetHandler.app/Contents/Resources
    
    # Copy the binary
    cp .build/release/MacPresetHandler MacPresetHandler.app/Contents/MacOS/
    
    # Copy resources
    cp -r MacPresetHandler/Assets.xcassets MacPresetHandler.app/Contents/Resources/
    cp MacPresetHandler/Info.plist MacPresetHandler.app/Contents/
    
    # Create Info.plist with proper structure for menu bar only app
    cat > MacPresetHandler.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacPresetHandler</string>
    <key>CFBundleIdentifier</key>
    <string>com.macpresethandler.app</string>
    <key>CFBundleName</key>
    <string>MacPresetHandler</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 Mac Preset Handler. All rights reserved.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
EOF
    
    echo "✅ App bundle created!"
    echo ""
    
    # Make the binary executable
    chmod +x MacPresetHandler.app/Contents/MacOS/MacPresetHandler
    
    echo "🎯 Build complete! The app is ready."
    echo ""
    echo "📁 App location: $(pwd)/MacPresetHandler.app"
    echo ""
    echo "🧹 Cleaning up any existing instances..."
    
    # Kill any existing instances before launching
    pkill -f MacPresetHandler 2>/dev/null || true
    sleep 1
    
    echo "🚀 Launching app directly (Ctrl+C will terminate it)..."
    
    # Launch the app directly in the same process so Ctrl+C works
    # This ensures the app closes when you press Ctrl+C
    ./MacPresetHandler.app/Contents/MacOS/MacPresetHandler
    
    echo "✅ App terminated. Terminal is now free."
    
else
    echo "❌ Build failed!"
    echo "Check the error messages above"
    exit 1
fi
