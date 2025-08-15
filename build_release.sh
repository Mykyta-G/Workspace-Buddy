#!/bin/bash

# Mac Preset Handler - Build and Package Script
# This script builds the app and creates a DMG for distribution

set -e

echo "🚀 Building Mac Preset Handler..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="MacPresetHandler"
BUNDLE_ID="com.macpresethandler.app"
VERSION="1.0.0"
BUILD_DIR="build"
RELEASE_DIR="release"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

# Clean previous builds
echo -e "${BLUE}Cleaning previous builds...${NC}"
rm -rf "${BUILD_DIR}"
rm -rf "${RELEASE_DIR}"
rm -f "${DMG_NAME}"

# Create build directories
mkdir -p "${BUILD_DIR}"
mkdir -p "${RELEASE_DIR}"

# Build the app using Xcode
echo -e "${BLUE}Building app with Xcode...${NC}"
xcodebuild -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}" \
    build

# Check if build was successful
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}"

# Find the built app
APP_PATH=$(find "${BUILD_DIR}" -name "*.app" -type d | head -n 1)

if [ -z "${APP_PATH}" ]; then
    echo -e "${RED}❌ Could not find built app!${NC}"
    exit 1
fi

echo -e "${BLUE}Found app at: ${APP_PATH}${NC}"

# Copy app to release directory
echo -e "${BLUE}Preparing release...${NC}"
cp -R "${APP_PATH}" "${RELEASE_DIR}/"

# Create DMG
echo -e "${BLUE}Creating DMG...${NC}"

# Create a temporary directory for DMG contents
DMG_TEMP_DIR="dmg_temp"
mkdir -p "${DMG_TEMP_DIR}"

# Copy app to temp directory
cp -R "${RELEASE_DIR}/${APP_NAME}.app" "${DMG_TEMP_DIR}/"

# Create Applications symlink
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# Create DMG using hdiutil
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TEMP_DIR}" -ov -format UDZO "${DMG_NAME}"

# Clean up temp directory
rm -rf "${DMG_TEMP_DIR}"

# Check if DMG was created successfully
if [ -f "${DMG_NAME}" ]; then
    echo -e "${GREEN}✅ DMG created successfully: ${DMG_NAME}${NC}"
    
    # Show DMG info
    echo -e "${BLUE}DMG Information:${NC}"
    ls -lh "${DMG_NAME}"
    
    echo -e "${GREEN}🎉 Release package ready!${NC}"
    echo -e "${YELLOW}You can now distribute: ${DMG_NAME}${NC}"
else
    echo -e "${RED}❌ Failed to create DMG!${NC}"
    exit 1
fi

# Optional: Open the DMG
read -p "Would you like to open the DMG? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "${DMG_NAME}"
fi

echo -e "${GREEN}🎯 Build and packaging complete!${NC}"

# Additional helpful information
echo -e "${BLUE}📋 Next Steps:${NC}"
echo -e "${YELLOW}1. Test the DMG:${NC} Double-click to mount and verify contents"
echo -e "${YELLOW}2. Install locally:${NC} Drag the app to Applications folder"
echo -e "${YELLOW}3. Distribute:${NC} Share the DMG file with users"
echo -e "${YELLOW}4. Upload:${NC} Add to GitHub releases for easy download"
echo ""
echo -e "${GREEN}🎉 Your Mac Preset Handler is ready for distribution!${NC}"
