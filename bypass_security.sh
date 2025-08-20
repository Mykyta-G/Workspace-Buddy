#!/bin/bash

# Mac Preset Handler - Security Bypass Script
# This script helps bypass the security warning temporarily

echo "🔓 Mac Preset Handler Security Bypass"
echo "====================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME="Workspace-Buddy"
APP_PATH="/Applications/${APP_NAME}.app"

echo -e "${BLUE}This script will help you bypass the security warning for Workspace-Buddy.${NC}"
echo ""

# Check if app exists
if [ ! -d "${APP_PATH}" ]; then
    echo -e "${RED}❌ Workspace-Buddy not found in Applications folder!${NC}"
    echo "Please install the app first by dragging it to Applications."
    exit 1
fi

echo -e "${GREEN}✅ Found Workspace-Buddy in Applications${NC}"
echo ""

echo -e "${YELLOW}⚠️  IMPORTANT: This is a temporary workaround.${NC}"
echo "The security warning appears because the app isn't code-signed by Apple."
echo ""

echo -e "${BLUE}Choose an option:${NC}"
echo "1. Remove quarantine attribute (recommended)"
echo "2. Show manual bypass steps"
echo "3. Exit"
echo ""

read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        echo ""
        echo -e "${BLUE}Removing quarantine attribute...${NC}"
        
        # Remove quarantine attribute
        xattr -rd com.apple.quarantine "${APP_PATH}"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Quarantine attribute removed successfully!${NC}"
            echo ""
            echo -e "${GREEN}🎉 You should now be able to launch Workspace-Buddy normally!${NC}"
            echo ""
            echo "Try launching the app from Applications or Spotlight."
        else
            echo -e "${RED}❌ Failed to remove quarantine attribute${NC}"
            echo "You may need administrator privileges."
            echo "Try running: sudo xattr -rd com.apple.quarantine /Applications/Workspace-Buddy.app"
        fi
        ;;
    2)
        echo ""
        echo -e "${BLUE}📋 Manual Bypass Steps:${NC}"
        echo ""
        echo "1. Right-click on Workspace-Buddy in Applications folder"
        echo "2. Select 'Open' from the context menu"
        echo "3. Click 'Open' in the security dialog that appears"
        echo "4. The app should now launch normally"
        echo ""
        echo -e "${YELLOW}Note: You'll need to repeat this process after each system update${NC}"
        ;;
    3)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice. Exiting...${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}📚 For a permanent solution:${NC}"
echo "• The developer should obtain a Developer ID certificate from Apple"
echo "• This would eliminate security warnings completely"
echo "• Check for updated versions of the app"
echo ""
echo -e "${GREEN}🎯 Workspace-Buddy should now work without security warnings!${NC}"
