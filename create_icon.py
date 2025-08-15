#!/usr/bin/env python3
"""
Simple script to create a basic app icon for Mac Preset Handler
This creates a placeholder icon using SF Symbols until a proper design is created
"""

import os
import subprocess
import tempfile

def create_icon_with_sf_symbols():
    """Create a simple icon using SF Symbols"""
    
    # Create a temporary Swift file to generate the icon
    swift_code = '''
import SwiftUI
import AppKit

// Create a simple icon using SF Symbols
let icon = NSImage(systemSymbolName: "rectangle.stack.3d.up", accessibilityDescription: "Mac Preset Handler")
let size = NSSize(width: 512, height: 512)

// Create a new image with the desired size
let newImage = NSImage(size: size)
newImage.lockFocus()

// Set background color (blue gradient)
let gradient = NSGradient(colors: [
    NSColor.systemBlue,
    NSColor.systemBlue.withAlphaComponent(0.8)
])
gradient.draw(in: NSRect(origin: .zero, size: size), angle: 45)

// Draw the SF Symbol
if let icon = icon {
    let iconSize = NSSize(width: 256, height: 256)
    let iconRect = NSRect(
        x: (size.width - iconSize.width) / 2,
        y: (size.height - iconSize.height) / 2,
        width: iconSize.width,
        height: iconSize.height
    )
    
    // Set white color for the icon
    NSColor.white.set()
    icon.draw(in: iconRect)
}

newImage.unlockFocus()

// Save the icon
if let tiffData = newImage.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    
    let desktopPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop")
        .appendingPathComponent("MacPresetHandler_Icon.png")
    
    try? pngData.write(to: desktopPath)
    print("Icon saved to Desktop as MacPresetHandler_Icon.png")
}
'''
    
    # Write the Swift code to a temporary file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.swift', delete=False) as f:
        f.write(swift_code)
        temp_file = f.name
    
    try:
        # Compile and run the Swift code
        print("Creating app icon...")
        result = subprocess.run(['swift', temp_file], capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Icon created successfully!")
            print("Icon saved to Desktop as MacPresetHandler_Icon.png")
            print("You can now use this as your app icon.")
        else:
            print("❌ Failed to create icon:")
            print(result.stderr)
            
    except FileNotFoundError:
        print("❌ Swift compiler not found. Please install Xcode Command Line Tools.")
    except Exception as e:
        print(f"❌ Error creating icon: {e}")
    finally:
        # Clean up temporary file
        os.unlink(temp_file)

if __name__ == "__main__":
    create_icon_with_sf_symbols()
