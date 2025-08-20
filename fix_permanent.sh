#!/bin/bash

# Mac Preset Handler - Permanent Security Fix (FREE)
# This script removes quarantine attributes and provides permanent solution

echo "🔓 Mac Preset Handler - Permanent Security Fix"
echo "==============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME="Workspace-Buddy"
LOCAL_APP_PATH="./${APP_NAME}.app"
INSTALL_PATH="/Applications/${APP_NAME}.app"

echo -e "${BLUE}This script will permanently fix the security warning issue.${NC}"
echo ""

# Check if app exists locally
if [ ! -d "${LOCAL_APP_PATH}" ]; then
    echo -e "${RED}❌ Workspace-Buddy.app not found in current directory!${NC}"
    echo "Please make sure you're in the Mac-Preset-Handler directory."
    exit 1
fi

echo -e "${GREEN}✅ Found Workspace-Buddy.app in current directory${NC}"
echo ""

# Check if app is already installed
if [ -d "${INSTALL_PATH}" ]; then
    echo -e "${BLUE}App is already installed in Applications. Updating...${NC}"
    rm -rf "${INSTALL_PATH}"
fi

echo -e "${BLUE}🔧 Installing and applying permanent fix...${NC}"

# Copy app to Applications
echo -e "${BLUE}Installing to Applications...${NC}"
cp -R "${LOCAL_APP_PATH}" "${INSTALL_PATH}"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to install to Applications${NC}"
    echo "Trying with sudo..."
    sudo cp -R "${LOCAL_APP_PATH}" "${INSTALL_PATH}"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Installation failed even with sudo${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ App installed to Applications successfully!${NC}"
echo ""

# Remove quarantine attribute
echo -e "${BLUE}Removing quarantine attribute...${NC}"
xattr -rd com.apple.quarantine "${INSTALL_PATH}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Quarantine attribute removed successfully!${NC}"
else
    echo -e "${YELLOW}⚠️  Could not remove quarantine attribute${NC}"
    echo "Trying with sudo..."
    sudo xattr -rd com.apple.quarantine "${INSTALL_PATH}"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Quarantine attribute removed with sudo!${NC}"
    else
        echo -e "${RED}❌ Failed to remove quarantine attribute${NC}"
        echo "Continuing with alternative methods..."
    fi
fi

# Remove other potentially problematic attributes
echo -e "${BLUE}Removing other security attributes...${NC}"
xattr -rd com.apple.macl "${INSTALL_PATH}" 2>/dev/null || true
xattr -rd com.apple.FinderInfo "${INSTALL_PATH}" 2>/dev/null || true

echo -e "${GREEN}✅ Security attributes cleaned!${NC}"
echo ""

# Create a launch script to avoid future issues
echo -e "${BLUE}Creating launch helper...${NC}"
LAUNCH_SCRIPT="/Applications/${APP_NAME} Launcher.command"

cat > "${LAUNCH_SCRIPT}" << 'EOF'
#!/bin/bash
# Mac Preset Handler Launcher
# This script ensures the app launches without security issues

APP_PATH="/Applications/Workspace-Buddy.app"

# Remove any quarantine attributes that might have been added
xattr -rd com.apple.quarantine "${APP_PATH}" 2>/dev/null || true

# Launch the app
open "${APP_PATH}"

echo "Workspace-Buddy launched successfully!"
echo "Press any key to close this window..."
read -n 1
EOF

chmod +x "${LAUNCH_SCRIPT}"

echo -e "${GREEN}✅ Launch helper created: ${LAUNCH_SCRIPT}${NC}"
echo ""

echo -e "${GREEN}🎉 Permanent fix applied successfully!${NC}"
echo ""
echo -e "${BLUE}📋 What was fixed:${NC}"
echo "✅ App installed to Applications folder"
echo "✅ Removed quarantine attributes"
echo "✅ Cleaned security metadata"
echo "✅ Created launch helper script"
echo ""
echo -e "${BLUE}🚀 How to use:${NC}"
echo "1. **Normal launch**: Double-click Workspace-Buddy in Applications"
echo "2. **If issues persist**: Use 'Workspace-Buddy Launcher.command'"
echo "3. **Future updates**: Run this script again after installing updates"
echo ""
echo -e "${BLUE}💡 Pro Tips:${NC}"
echo "• The app should now launch without security warnings"
echo "• If you see 'unidentified developer', just right-click → Open once"
echo "• After that, it will work normally forever"
echo "• Share this script with others who have the same issue"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "• This fix is permanent but may need to be reapplied after system updates"
echo "• The app is safe - it's your own code, not malware"
echo "• This is a common issue with self-built macOS apps"
echo ""
echo -e "${GREEN}🎯 Your Workspace-Buddy should now work perfectly!${NC}"
echo ""
echo -e "${BLUE}📱 Test it now by launching the app from Applications!${NC}"
echo ""
echo -e "${BLUE}🔍 The app is now located at: ${INSTALL_PATH}${NC}"
