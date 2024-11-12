#!/bin/bash

echo "Minecraft Screentime Uninstaller"
echo "==============================="
echo "This will remove all components of Minecraft Screentime."
echo "Press Enter to continue or Ctrl+C to cancel..."
read -r

# Unload and remove LaunchAgent
echo "Removing launch agent..."
launchctl unload "$HOME/Library/LaunchAgents/com.minecraft.screentime.plist" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/com.minecraft.screentime.plist"

# Remove application directory
echo "Removing application files..."
APP_DIR="$HOME/Library/Application Support/MinecraftScreentime"
rm -rf "$APP_DIR"

# Remove log files
echo "Removing log files..."
rm -f "$HOME/Library/Application Support/minecraft/logs/screentime.log"
rm -f "$HOME/Library/Application Support/minecraft/logs/screentime_*.log"

echo "Uninstallation complete!"
echo ""
echo "Note: The shared iCloud configuration folder (MinecraftScreentimeConfig)"
echo "was not removed. If you want to remove it:"
echo "1. Open iCloud Drive on the parent's device"
echo "2. Delete the MinecraftScreentimeConfig folder"
echo ""
echo "You may also want to remove Full Disk Access permission for bash:"
echo "1. Open System Settings"
echo "2. Go to Privacy & Security → Full Disk Access"
echo "3. Remove /bin/bash from the list if you don't need it for other applications"
