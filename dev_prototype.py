#!/usr/bin/env python3
"""
Mac Preset Handler - Development Prototype
A simple demonstration of the workspace preset concept using Python and tkinter.

This prototype shows:
- Creating and managing workspace presets
- Basic app launching simulation
- Simple GUI for testing the concept

Run with: python3 dev_prototype.py
"""

import tkinter as tk
from tkinter import ttk, messagebox
import json
import os
import sys
from typing import Dict, List, Optional

class PresetHandler:
    def __init__(self):
        self.presets_file = "presets.json"
        self.presets = self.load_presets()
        self.current_preset = None
        
    def load_presets(self) -> Dict:
        """Load presets from JSON file or create default ones"""
        if os.path.exists(self.presets_file):
            try:
                with open(self.presets_file, 'r') as f:
                    return json.load(f)
            except:
                pass
        
        # Default presets
        default_presets = {
            "Work": {
                "description": "Productivity and development workspace",
                "apps": ["Safari", "Xcode", "Terminal", "Slack", "Notes"],
                "close_previous": True
            },
            "School": {
                "description": "Educational and learning workspace", 
                "apps": ["Safari", "Pages", "Keynote", "Numbers", "Mail"],
                "close_previous": True
            },
            "Gaming": {
                "description": "Gaming and entertainment workspace",
                "apps": ["Steam", "Discord", "Spotify", "Safari"],
                "close_previous": False
            },
            "Relax": {
                "description": "Relaxation and social media workspace",
                "apps": ["Safari", "Messages", "Photos", "Music", "TV"],
                "close_previous": False
            }
        }
        
        self.save_presets(default_presets)
        return default_presets
    
    def save_presets(self, presets: Dict):
        """Save presets to JSON file"""
        with open(self.presets_file, 'w') as f:
            json.dump(presets, f, indent=2)
    
    def switch_to_preset(self, preset_name: str):
        """Switch to a specific preset (simulated)"""
        if preset_name not in self.presets:
            return False
            
        preset = self.presets[preset_name]
        
        # Simulate app management
        if self.current_preset and preset.get("close_previous", True):
            print(f"🔄 Closing apps from previous preset: {self.current_preset}")
        
        print(f"🚀 Switching to preset: {preset_name}")
        print(f"📱 Opening apps: {', '.join(preset['apps'])}")
        print(f"💡 Description: {preset['description']}")
        
        self.current_preset = preset_name
        return True
    
    def add_preset(self, name: str, description: str, apps: List[str], close_previous: bool):
        """Add a new preset"""
        self.presets[name] = {
            "description": description,
            "apps": apps,
            "close_previous": close_previous
        }
        self.save_presets(self.presets)
    
    def delete_preset(self, name: str):
        """Delete a preset"""
        if name in self.presets:
            del self.presets[name]
            self.save_presets(self.presets)
            return True
        return False

class PresetHandlerGUI:
    def __init__(self):
        self.preset_handler = PresetHandler()
        
        # Create main window
        self.root = tk.Tk()
        self.root.title("Mac Preset Handler - Development Prototype")
        self.root.geometry("600x500")
        self.root.resizable(True, True)
        
        # Configure style
        style = ttk.Style()
        style.theme_use('clam')
        
        self.setup_ui()
        
    def setup_ui(self):
        """Setup the user interface"""
        # Main frame
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Configure grid weights
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main_frame.columnconfigure(1, weight=1)
        
        # Title
        title_label = ttk.Label(main_frame, text="Mac Preset Handler", 
                               font=("Helvetica", 16, "bold"))
        title_label.grid(row=0, column=0, columnspan=3, pady=(0, 20))
        
        subtitle_label = ttk.Label(main_frame, 
                                  text="Development Prototype - Test the concept!", 
                                  font=("Helvetica", 10))
        subtitle_label.grid(row=1, column=0, columnspan=3, pady=(0, 20))
        
        # Preset selection
        ttk.Label(main_frame, text="Select Preset:").grid(row=2, column=0, sticky=tk.W, pady=5)
        
        self.preset_var = tk.StringVar()
        preset_combo = ttk.Combobox(main_frame, textvariable=self.preset_var, 
                                   values=list(self.preset_handler.presets.keys()),
                                   state="readonly", width=30)
        preset_combo.grid(row=2, column=1, sticky=(tk.W, tk.E), padx=(10, 0), pady=5)
        preset_combo.bind('<<ComboboxSelected>>', self.on_preset_selected)
        
        # Switch button
        switch_btn = ttk.Button(main_frame, text="Switch to Preset", 
                               command=self.switch_preset)
        switch_btn.grid(row=2, column=2, padx=(10, 0), pady=5)
        
        # Preset info
        ttk.Label(main_frame, text="Preset Information:").grid(row=3, column=0, 
                                                              sticky=tk.W, pady=(20, 5))
        
        self.info_text = tk.Text(main_frame, height=8, width=50, wrap=tk.WORD)
        self.info_text.grid(row=4, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=5)
        
        # Scrollbar for info text
        info_scrollbar = ttk.Scrollbar(main_frame, orient=tk.VERTICAL, command=self.info_text.yview)
        info_scrollbar.grid(row=4, column=3, sticky=(tk.N, tk.S))
        self.info_text.configure(yscrollcommand=info_scrollbar.set)
        
        # Buttons frame
        buttons_frame = ttk.Frame(main_frame)
        buttons_frame.grid(row=5, column=0, columnspan=3, pady=(20, 0))
        
        # Add preset button
        add_btn = ttk.Button(buttons_frame, text="Add New Preset", 
                            command=self.show_add_preset_dialog)
        add_btn.pack(side=tk.LEFT, padx=(0, 10))
        
        # Delete preset button
        delete_btn = ttk.Button(buttons_frame, text="Delete Preset", 
                               command=self.delete_preset)
        delete_btn.pack(side=tk.LEFT, padx=(0, 10))
        
        # Exit button
        exit_btn = ttk.Button(buttons_frame, text="Exit Prototype", 
                             command=self.exit_prototype)
        exit_btn.pack(side=tk.LEFT, padx=(0, 10))
        
        # Status bar
        self.status_var = tk.StringVar()
        self.status_var.set("Ready - Select a preset to get started")
        status_label = ttk.Label(main_frame, textvariable=self.status_var, 
                                relief=tk.SUNKEN, anchor=tk.W)
        status_label.grid(row=6, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(20, 0))
        
        # Set initial preset if available
        if self.preset_handler.presets:
            preset_combo.set(list(self.preset_handler.presets.keys())[0])
            self.update_info_display()
    
    def on_preset_selected(self, event):
        """Handle preset selection"""
        self.update_info_display()
    
    def update_info_display(self):
        """Update the information display"""
        preset_name = self.preset_var.get()
        if not preset_name or preset_name not in self.preset_handler.presets:
            return
            
        preset = self.preset_handler.presets[preset_name]
        
        info_text = f"Preset: {preset_name}\n"
        info_text += f"Description: {preset['description']}\n\n"
        info_text += f"Apps to open:\n"
        for app in preset['apps']:
            info_text += f"  • {app}\n"
        info_text += f"\nClose previous apps: {'Yes' if preset['close_previous'] else 'No'}"
        
        self.info_text.delete(1.0, tk.END)
        self.info_text.insert(1.0, info_text)
    
    def switch_preset(self):
        """Switch to the selected preset"""
        preset_name = self.preset_var.get()
        if not preset_name:
            messagebox.showwarning("Warning", "Please select a preset first!")
            return
            
        if self.preset_handler.switch_to_preset(preset_name):
            self.status_var.set(f"Switched to {preset_name} preset successfully!")
            messagebox.showinfo("Success", f"Switched to {preset_name} preset!\n\nThis is a simulation - in the real app, this would:\n• Close previous workspace apps (if enabled)\n• Launch the specified applications\n• Apply any workspace-specific settings")
        else:
            self.status_var.set("Failed to switch preset")
            messagebox.showerror("Error", "Failed to switch preset!")
    
    def show_add_preset_dialog(self):
        """Show dialog to add a new preset"""
        dialog = tk.Toplevel(self.root)
        dialog.title("Add New Preset")
        dialog.geometry("400x300")
        dialog.transient(self.root)
        dialog.grab_set()
        
        # Dialog content
        ttk.Label(dialog, text="Preset Name:").grid(row=0, column=0, sticky=tk.W, pady=5, padx=5)
        name_entry = ttk.Entry(dialog, width=30)
        name_entry.grid(row=0, column=1, sticky=(tk.W, tk.E), pady=5, padx=5)
        
        ttk.Label(dialog, text="Description:").grid(row=1, column=0, sticky=tk.W, pady=5, padx=5)
        desc_entry = ttk.Entry(dialog, width=30)
        desc_entry.grid(row=1, column=1, sticky=(tk.W, tk.E), pady=5, padx=5)
        
        ttk.Label(dialog, text="Apps (comma-separated):").grid(row=2, column=0, sticky=tk.W, pady=5, padx=5)
        apps_entry = ttk.Entry(dialog, width=30)
        apps_entry.grid(row=2, column=1, sticky=(tk.W, tk.E), pady=5, padx=5)
        apps_entry.insert(0, "Safari, Mail, Notes")
        
        close_var = tk.BooleanVar(value=True)
        close_check = ttk.Checkbutton(dialog, text="Close previous apps when switching", 
                                     variable=close_var)
        close_check.grid(row=3, column=0, columnspan=2, sticky=tk.W, pady=5, padx=5)
        
        # Buttons
        button_frame = ttk.Frame(dialog)
        button_frame.grid(row=4, column=0, columnspan=2, pady=20)
        
        def add_preset():
            name = name_entry.get().strip()
            description = desc_entry.get().strip()
            apps_text = apps_entry.get().strip()
            
            if not name or not description or not apps_text:
                messagebox.showwarning("Warning", "Please fill in all fields!")
                return
                
            apps = [app.strip() for app in apps_text.split(",") if app.strip()]
            
            try:
                self.preset_handler.add_preset(name, description, apps, close_var.get())
                self.preset_var.set(name)
                self.update_info_display()
                dialog.destroy()
                self.status_var.set(f"Added new preset: {name}")
                messagebox.showinfo("Success", f"Preset '{name}' added successfully!")
            except Exception as e:
                messagebox.showerror("Error", f"Failed to add preset: {str(e)}")
        
        ttk.Button(button_frame, text="Add Preset", command=add_preset).pack(side=tk.LEFT, padx=5)
        ttk.Button(button_frame, text="Cancel", command=dialog.destroy).pack(side=tk.LEFT, padx=5)
    
    def delete_preset(self):
        """Delete the selected preset"""
        preset_name = self.preset_var.get()
        if not preset_name:
            messagebox.showwarning("Warning", "Please select a preset first!")
            return
            
        if messagebox.askyesno("Confirm Delete", f"Are you sure you want to delete the '{preset_name}' preset?"):
            if self.preset_handler.delete_preset(preset_name):
                # Update UI
                preset_combo = self.root.nametowidget(self.preset_var.get())
                preset_combo['values'] = list(self.preset_handler.presets.keys())
                if self.preset_handler.presets:
                    preset_combo.set(list(self.preset_handler.presets.keys())[0])
                else:
                    preset_combo.set("")
                self.update_info_display()
                self.status_var.set(f"Deleted preset: {preset_name}")
                messagebox.showinfo("Success", f"Preset '{preset_name}' deleted successfully!")
            else:
                messagebox.showerror("Error", "Failed to delete preset!")
    
    def exit_prototype(self):
        """Exit the prototype"""
        if messagebox.askyesno("Exit", "Are you sure you want to exit the prototype?"):
            self.root.quit()
    
    def run(self):
        """Run the GUI"""
        self.root.mainloop()

def main():
    """Main function"""
    print("🚀 Starting Mac Preset Handler Development Prototype...")
    print("📱 This prototype demonstrates the workspace preset concept")
    print("💡 Features: Create presets, switch between them, manage apps")
    print("🔧 Run with: python3 dev_prototype.py")
    print()
    
    try:
        app = PresetHandlerGUI()
        app.run()
    except KeyboardInterrupt:
        print("\n👋 Prototype interrupted by user")
    except Exception as e:
        print(f"❌ Error running prototype: {e}")
        sys.exit(1)
    
    print("👋 Prototype finished. Thanks for testing!")

if __name__ == "__main__":
    main()
