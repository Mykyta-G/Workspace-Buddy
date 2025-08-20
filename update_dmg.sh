#!/bin/bash

# Workspace-Buddy DMG Update Script
# This script updates the DMG with the latest version of the app

echo "🔄 Updating Workspace-Buddy DMG..."
echo "====================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="Workspace-Buddy"
VERSION="1.0.1"
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
BUILD_DIR="build"
SOURCE_APP="${BUILD_DIR}/Workspace-Buddy/Build/Products/Release/${APP_NAME}.app"

echo -e "${BLUE}Looking for built app...${NC}"

# Check if the built app exists
if [ ! -d "${SOURCE_APP}" ]; then
    echo -e "${RED}❌ Built app not found at: ${SOURCE_APP}${NC}"
    echo ""
    echo -e "${YELLOW}💡 You need to build the app first:${NC}"
    echo "   1. Open Workspace-Buddy.xcodeproj in Xcode"
    echo "   2. Select Release configuration"
    echo "   3. Product → Clean Build Folder"
    echo "   4. Product → Build (⌘B)"
    echo ""
    echo -e "${YELLOW}Or run the build script:${NC}"
    echo "   chmod +x build_release.sh && ./build_release.sh"
    exit 1
fi

echo -e "${GREEN}✅ Found built app at: ${SOURCE_APP}${NC}"

# Remove existing DMG if it exists
if [ -f "${DMG_NAME}" ]; then
    echo -e "${BLUE}Removing existing DMG: ${DMG_NAME}${NC}"
    rm -f "${DMG_NAME}"
fi

# Create a temporary directory for DMG contents
echo -e "${BLUE}Creating temporary directory for DMG...${NC}"
DMG_TEMP_DIR="dmg_temp_$(date +%s)"
mkdir -p "${DMG_TEMP_DIR}"

# Copy app to temp directory
echo -e "${BLUE}Copying app to temporary directory...${NC}"
cp -R "${SOURCE_APP}" "${DMG_TEMP_DIR}/"

# Create Applications symlink
echo -e "${BLUE}Creating Applications folder shortcut...${NC}"
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# Create DMG using hdiutil
echo -e "${BLUE}Creating DMG...${NC}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TEMP_DIR}" -ov -format UDZO "${DMG_NAME}"

# Check if DMG was created successfully
if [ -f "${DMG_NAME}" ]; then
    echo -e "${GREEN}✅ DMG created successfully: ${DMG_NAME}${NC}"
    
    # Show DMG info
    echo -e "${BLUE}DMG Information:${NC}"
    ls -lh "${DMG_NAME}"
    
    # Clean up temp directory
    rm -rf "${DMG_TEMP_DIR}"
    
    echo ""
    echo -e "${GREEN}🎉 DMG update complete!${NC}"
    echo ""
    echo -e "${BLUE}📋 What's new in v${VERSION}:${NC}"
    echo "✅ Fixed threading crash (EXC_BAD_ACCESS)"
    echo "✅ Improved login item registration"
    echo "✅ Better accessibility permission handling"
    echo "✅ Enhanced menu options for startup management"
    echo "✅ More reliable app launching"
    echo ""
    echo -e "${BLUE}📥 How to use:${NC}"
    echo "1. Double-click the DMG to mount it"
    echo "2. Drag Workspace-Buddy to Applications"
    echo "3. Launch the app - it should work without crashes!"
    echo ""
    echo -e "${GREEN}🎯 Your updated DMG is ready for distribution!${NC}"
    
    # Optional: Open the DMG
    read -p "Would you like to open the DMG? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "${DMG_NAME}"
    fi
    
else
    echo -e "${RED}❌ Failed to create DMG!${NC}"
    # Clean up temp directory
    rm -rf "${DMG_TEMP_DIR}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎯 DMG update process complete!${NC}"
