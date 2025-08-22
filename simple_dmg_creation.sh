#!/bin/bash

# Simple DMG Creation - Bypasses Code Signing Issues
# This script builds the app without code signing and creates a DMG

set -e

echo "🚀 Simple DMG Creation for Workspace-Buddy"
echo "==========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME="Workspace-Buddy"
BUILD_DIR="build"
RELEASE_DIR="release"

echo -e "${BLUE}Step 1: Cleaning previous builds...${NC}"
rm -rf "${BUILD_DIR}"
rm -rf "${RELEASE_DIR}"
rm -f "${APP_NAME}-*.dmg"

echo -e "${BLUE}Step 2: Building the app WITHOUT code signing...${NC}"
xcodebuild -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
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

echo -e "${BLUE}Step 3: Creating release directory...${NC}"
mkdir -p "${RELEASE_DIR}"

# Copy app to release directory
cp -R "${APP_PATH}" "${RELEASE_DIR}/"

echo -e "${BLUE}Step 4: Creating DMG...${NC}"

# Create a temporary directory for DMG contents
DMG_TEMP_DIR="dmg_temp"
mkdir -p "${DMG_TEMP_DIR}"

# Copy app to temp directory
cp -R "${RELEASE_DIR}/${APP_NAME}.app" "${DMG_TEMP_DIR}/"

# Create Applications symlink
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# Create DMG using hdiutil
DMG_NAME="${APP_NAME}-Simple-v1.0.dmg"
echo -e "${BLUE}Creating DMG: ${DMG_NAME}${NC}"

hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_NAME}"

# Clean up temp directory
rm -rf "${DMG_TEMP_DIR}"

# Check if DMG was created successfully
if [ -f "${DMG_NAME}" ]; then
    echo -e "${GREEN}✅ DMG created successfully: ${DMG_NAME}${NC}"
    
    # Show DMG info
    echo -e "${BLUE}DMG Information:${NC}"
    ls -lh "${DMG_NAME}"
    
    echo ""
    echo -e "${GREEN}🎉 DMG creation complete!${NC}"
    echo ""
    echo -e "${BLUE}📋 What this DMG contains:${NC}"
    echo "✅ Workspace-Buddy app (built without code signing)"
    echo "✅ Applications folder shortcut"
    echo "✅ UDZO format for good compression"
    echo ""
    echo -e "${YELLOW}⚠️  Note: This app is not code signed${NC}"
    echo "   Users may see security warnings when installing"
    echo "   They can still use 'Open Anyway' to install it"
    echo ""
    echo -e "${BLUE}📥 How to use:${NC}"
    echo "1. Double-click the DMG to mount it"
    echo "2. Drag Workspace-Buddy to Applications"
    echo "3. Right-click the app and select 'Open'"
    echo "4. Click 'Open' in the security dialog"
    echo ""
    echo -e "${GREEN}🎯 Your DMG is ready for distribution!${NC}"
    
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
echo -e "${GREEN}🎯 Simple DMG creation successful!${NC}"
echo -e "${YELLOW}💡 This approach bypasses code signing issues by building without it${NC}"
