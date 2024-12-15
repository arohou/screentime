#!/bin/bash

echo "Minecraft Screentime Uninstaller"
echo "==============================="
echo "This will remove all components of Minecraft Screentime."
echo "Press Enter to continue or Ctrl+C to cancel..."
read -r

# Define paths
APP_DIR="$HOME/Library/Application Support/MinecraftScreentime"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.minecraft.screentime.plist"
MINECRAFT_DIR="$HOME/Library/Application Support/minecraft"
ICLOUD_BASE="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
CONFIG_DIR="$ICLOUD_BASE/MinecraftScreentimeConfig"
USAGE_DIR="$ICLOUD_BASE/MinecraftUsageLogs"

# Unload and remove LaunchAgent
echo "Removing launch agent..."
launchctl unload "$LAUNCH_AGENT" 2>/dev/null
rm -f "$LAUNCH_AGENT"

# Remove application directory
echo "Removing application files..."
rm -rf "$APP_DIR"

# Remove log files
echo "Removing log files..."
rm -f "$MINECRAFT_DIR/logs/screentime.log"
rm -f "$MINECRAFT_DIR/logs/screentime_*.log"

# Clean up any temporary files that might have been created
rm -f /tmp/minecraft-screentime-*

echo "Uninstallation complete!"
echo ""
echo "Note: The following iCloud folders were NOT removed:"
echo "1. MinecraftScreentimeConfig (contains time limit settings)"
echo "2. MinecraftUsageLogs (contains usage history)"
echo ""
echo "To completely remove all data:"
echo ""
echo "On the PARENT'S device:"
echo "1. Open iCloud Drive"
echo "2. Delete the 'MinecraftScreentimeConfig' folder"
echo "3. Delete the 'MinecraftUsageLogs' folder"
echo ""
echo "You may also want to remove Full Disk Access permission for bash:"
echo "1. Open System Settings"
echo "2. Go to Privacy & Security → Full Disk Access"
echo "3. Remove /bin/bash from the list if you don't need it for other applications"