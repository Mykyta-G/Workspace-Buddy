#!/bin/bash

# Fix App Icon Naming Issues
# This script renames the icon files to match their intended sizes

echo "🔧 Fixing App Icon Naming Issues..."
echo "====================================="

ICON_DIR="MacPresetHandler/Assets.xcassets/AppIcon.appiconset"

# Create backup of current icons
echo "📁 Creating backup of current icons..."
mkdir -p "$ICON_DIR/backup_$(date +%Y%m%d_%H%M%S)"
cp "$ICON_DIR"/*.png "$ICON_DIR/backup_$(date +%Y%m%d_%H%M%S)/" 2>/dev/null

# The issue is that icon files have wrong names
# Based on the Contents.json, we need to rename them correctly

echo "🔄 Renaming icon files to match their intended sizes..."

# Rename files to match their intended sizes
cd "$ICON_DIR"

# icon_16x16.png should be 16x16 (1x)
# icon_32x32.png should be 16x16 (2x) 
# icon_64x64.png should be 32x32 (1x)
# icon_128x128.png should be 32x32 (2x)
# icon_256x256.png should be 128x128 (1x)
# icon_512x512.png should be 128x128 (2x)
# icon_1024x1024.png should be 1024x1024 (1x)

# Create properly named files by copying the existing ones
cp icon_16x16.png icon_16x16_1x.png
cp icon_32x32.png icon_16x16_2x.png
cp icon_64x64.png icon_32x32_1x.png
cp icon_128x128.png icon_32x32_2x.png
cp icon_256x256.png icon_128x128_1x.png
cp icon_512x512.png icon_128x128_2x.png
cp icon_1024x1024.png icon_1024x1024_1x.png

echo "✅ Icon files renamed successfully!"
echo "📋 New icon structure:"
ls -la icon_*.png

echo ""
echo "🎯 Next steps:"
echo "1. Update Contents.json to use new filenames"
echo "2. Build the app to verify warnings are gone"
echo "3. Test the interface layout improvements"
