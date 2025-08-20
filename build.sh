#!/bin/bash

# Mac Preset Handler - Build Script
# This script builds the app using Xcode for proper asset catalog handling

echo "🚀 Building Mac Preset Handler..."
echo "=================================="

# Check if Xcode is available
if command -v xcodebuild &> /dev/null; then
    echo "✅ Xcode found: $(xcodebuild -version | head -n 1)"
else
    echo "❌ Xcode not found. Please install Xcode from the App Store."
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build
rm -rf Workspace-Buddy.app
echo "✅ Cleaned"

# Build the app using Xcode (skip code signing for development)
echo "🔨 Building app with Xcode (development mode)..."
xcodebuild -project Workspace-Buddy.xcodeproj \
    -scheme Workspace-Buddy \
    -configuration Debug \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    
    # Find the built app
    APP_PATH=$(find build -name "*.app" -type d | head -n 1)
    
    if [ -z "$APP_PATH" ]; then
        echo "❌ Could not find built app!"
        exit 1
    fi
    
    echo "📱 Found app at: $APP_PATH"
    
    # Copy to current directory for easy access
    cp -R "$APP_PATH" ./Workspace-Buddy.app
    
    echo "✅ App bundle ready!"
    echo ""
    
    echo "🎯 Build complete! The app is ready."
    echo ""
    echo "📁 App location: $(pwd)/Workspace-Buddy.app"
    echo ""
    echo "🧹 Cleaning up any existing instances..."
    
    # Kill any existing instances before launching
    pkill -f Workspace-Buddy 2>/dev/null || true
    sleep 1
    
    echo "🚀 Launching app..."
    
    # Launch the app
    open ./Workspace-Buddy.app
    
else
    echo "❌ Build failed!"
    echo ""
    echo "💡 Try these troubleshooting steps:"
    echo "   1. Open the project in Xcode"
    echo "   2. Clean the build folder (Product > Clean Build Folder)"
    echo "   3. Check that all asset files are properly referenced"
    echo "   4. Ensure the AppIcon is properly configured"
    exit 1
fi
