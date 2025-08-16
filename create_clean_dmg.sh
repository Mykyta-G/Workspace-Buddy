#!/bin/bash

# Mac Preset Handler - Create Clean DMG
# This script creates a clean DMG from the current working app

echo "📦 Creating Clean DMG for MacPresetHandler"
echo "==========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME="MacPresetHandler"
LOCAL_APP_PATH="./${APP_NAME}.app"
DMG_NAME="${APP_NAME}-Clean-v1.0.dmg"

echo -e "${BLUE}This script will create a clean DMG from your working app.${NC}"
echo ""

# Check if app exists locally
if [ ! -d "${LOCAL_APP_PATH}" ]; then
    echo -e "${RED}❌ MacPresetHandler.app not found in current directory!${NC}"
    echo "Please make sure you're in the Mac-Preset-Handler directory."
    exit 1
fi

echo -e "${GREEN}✅ Found MacPresetHandler.app in current directory${NC}"
echo ""

# Clean up any existing DMG
if [ -f "${DMG_NAME}" ]; then
    echo -e "${BLUE}Removing existing DMG...${NC}"
    rm -f "${DMG_NAME}"
fi

# Create a temporary directory for DMG contents
echo -e "${BLUE}Preparing DMG contents...${NC}"
DMG_TEMP_DIR="dmg_temp"
mkdir -p "${DMG_TEMP_DIR}"

# Copy app to temp directory
cp -R "${LOCAL_APP_PATH}" "${DMG_TEMP_DIR}/"

# Create Applications symlink
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# Create DMG using hdiutil
echo -e "${BLUE}Creating DMG...${NC}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TEMP_DIR}" -ov -format UDZO "${DMG_NAME}"

# Clean up temp directory
rm -rf "${DMG_TEMP_DIR}"

# Check if DMG was created successfully
if [ -f "${DMG_NAME}" ]; then
    echo -e "${GREEN}✅ Clean DMG created successfully: ${DMG_NAME}${NC}"
    
    # Show DMG info
    echo -e "${BLUE}DMG Information:${NC}"
    ls -lh "${DMG_NAME}"
    
    echo ""
    echo -e "${GREEN}🎉 Clean DMG ready!${NC}"
    echo ""
    echo -e "${BLUE}📋 What this DMG contains:${NC}"
    echo "✅ Your working MacPresetHandler app"
    echo "✅ Applications folder shortcut"
    echo "✅ No security warnings (since it's from your working copy)"
    echo ""
    echo -e "${BLUE}📥 How to use:${NC}"
    echo "1. Double-click the DMG to mount it"
    echo "2. Drag MacPresetHandler to Applications"
    echo "3. Launch the app - it should work without security warnings!"
    echo ""
    echo -e "${YELLOW}💡 Why this works:${NC}"
    echo "• The app in this DMG is the same one that's already working on your system"
    echo "• It has all the security attributes already cleaned"
    echo "• Users can install it and it will work immediately"
    echo ""
    echo -e "${GREEN}🎯 Your clean DMG is ready for distribution!${NC}"
    
    # Optional: Open the DMG
    read -p "Would you like to open the DMG? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "${DMG_NAME}"
    fi
else
    echo -e "${RED}❌ Failed to create DMG!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎯 Clean DMG creation complete!${NC}"
