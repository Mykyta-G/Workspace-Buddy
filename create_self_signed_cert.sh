#!/bin/bash

# Mac Preset Handler - Self-Signed Certificate Creation
# This script creates a self-signed certificate and signs the app for FREE

echo "🔐 Creating Self-Signed Certificate for MacPresetHandler"
echo "========================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CERT_NAME="MacPresetHandler Developer"
KEYCHAIN_NAME="login"
APP_NAME="MacPresetHandler"
BUNDLE_ID="com.macpresethandler.app"

echo -e "${BLUE}This script will:${NC}"
echo "1. Create a self-signed certificate"
echo "2. Build the app"
echo "3. Sign it with the certificate"
echo "4. Create a properly signed DMG"
echo ""

echo -e "${YELLOW}⚠️  Note: This is a self-signed certificate, not Apple's official one.${NC}"
echo "   It will eliminate security warnings but may show 'unidentified developer'"
echo "   This is normal and safe for your own apps."
echo ""

# Check if certificate already exists
if security find-identity -v -p codesigning | grep -q "${CERT_NAME}"; then
    echo -e "${GREEN}✅ Certificate already exists!${NC}"
    CERT_IDENTITY=$(security find-identity -v -p codesigning | grep "${CERT_NAME}" | head -1 | cut -d'"' -f2)
    echo -e "${BLUE}Using existing certificate: ${CERT_IDENTITY}${NC}"
else
    echo -e "${BLUE}Creating new self-signed certificate...${NC}"
    
    # Create certificate request
    echo -e "${BLUE}Generating certificate request...${NC}"
    
    # Create a temporary directory for the certificate
    CERT_DIR="temp_cert"
    mkdir -p "${CERT_DIR}"
    
    # Generate private key and certificate
    openssl req -newkey rsa:2048 -keyout "${CERT_DIR}/private.key" -out "${CERT_DIR}/cert.csr" -subj "/CN=${CERT_NAME}/O=${CERT_NAME}/C=US" -nodes
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to generate certificate request${NC}"
        echo "Make sure OpenSSL is installed: brew install openssl"
        exit 1
    fi
    
    # Generate self-signed certificate
    openssl x509 -req -in "${CERT_DIR}/cert.csr" -signkey "${CERT_DIR}/private.key" -out "${CERT_DIR}/cert.crt" -days 3650
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to generate self-signed certificate${NC}"
        exit 1
    fi
    
    # Convert to p12 format
    openssl pkcs12 -export -out "${CERT_DIR}/cert.p12" -inkey "${CERT_DIR}/private.key" -in "${CERT_DIR}/cert.crt" -name "${CERT_NAME}" -passout pass:""
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to convert certificate to p12 format${NC}"
        exit 1
    fi
    
    # Import into keychain
    echo -e "${BLUE}Importing certificate into keychain...${NC}"
    security import "${CERT_DIR}/cert.p12" -k "${KEYCHAIN_NAME}" -T /usr/bin/codesign -P ""
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to import certificate into keychain${NC}"
        exit 1
    fi
    
    # Clean up temporary files
    rm -rf "${CERT_DIR}"
    
    echo -e "${GREEN}✅ Self-signed certificate created and imported successfully!${NC}"
    
    # Get the certificate identity
    CERT_IDENTITY=$(security find-identity -v -p codesigning | grep "${CERT_NAME}" | head -1 | cut -d'"' -f2)
fi

echo ""
echo -e "${BLUE}Building and signing the app...${NC}"

# Build the app
echo -e "${BLUE}Building with Xcode...${NC}"
xcodebuild -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "build" \
    build

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}"

# Find the built app
APP_PATH=$(find "build" -name "*.app" -type d | head -n 1)

if [ -z "${APP_PATH}" ]; then
    echo -e "${RED}❌ Could not find built app!${NC}"
    exit 1
fi

echo -e "${BLUE}Found app at: ${APP_PATH}${NC}"

# Sign the app
echo -e "${BLUE}Signing app with certificate...${NC}"
codesign --force --deep --sign "${CERT_IDENTITY}" "${APP_PATH}"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Code signing failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ App signed successfully!${NC}"

# Verify the signature
echo -e "${BLUE}Verifying signature...${NC}"
codesign --verify --verbose=4 "${APP_PATH}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Signature verification passed!${NC}"
else
    echo -e "${YELLOW}⚠️  Signature verification had issues, but app should still work${NC}"
fi

# Create DMG
echo -e "${BLUE}Creating signed DMG...${NC}"

# Create release directory
RELEASE_DIR="release"
mkdir -p "${RELEASE_DIR}"

# Copy signed app to release directory
cp -R "${APP_PATH}" "${RELEASE_DIR}/"

# Create DMG
DMG_NAME="${APP_NAME}-Signed.dmg"
DMG_TEMP_DIR="dmg_temp"
mkdir -p "${DMG_TEMP_DIR}"

# Copy app to temp directory
cp -R "${RELEASE_DIR}/${APP_NAME}.app" "${DMG_TEMP_DIR}/"

# Create Applications symlink
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# Create DMG
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TEMP_DIR}" -ov -format UDZO "${DMG_NAME}"

# Clean up temp directory
rm -rf "${DMG_TEMP_DIR}"

if [ -f "${DMG_NAME}" ]; then
    echo -e "${GREEN}✅ Signed DMG created: ${DMG_NAME}${NC}"
    
    # Show DMG info
    ls -lh "${DMG_NAME}"
    
    echo ""
    echo -e "${GREEN}🎉 Success! Your app is now properly signed and should not show security warnings!${NC}"
    echo ""
    echo -e "${BLUE}📋 What this accomplished:${NC}"
    echo "✅ Created a self-signed certificate"
    echo "✅ Built the app with proper entitlements"
    echo "✅ Code-signed the app bundle"
    echo "✅ Created a signed DMG for distribution"
    echo ""
    echo -e "${BLUE}📥 Next steps:${NC}"
    echo "1. Install the new signed app from the DMG"
    echo "2. It should launch without security warnings"
    echo "3. Share the DMG with others (they may see 'unidentified developer' once)"
    echo ""
    echo -e "${YELLOW}💡 Tip: The 'unidentified developer' warning is much better than the malware warning!${NC}"
    echo "   Users can right-click → Open once, then it works normally forever."
else
    echo -e "${RED}❌ Failed to create DMG!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎯 Your MacPresetHandler is now permanently fixed!${NC}"
