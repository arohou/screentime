#!/bin/bash

echo "Welcome to Minecraft Screentime Installer!"
echo "This will help you set up screentime limits for Minecraft."

# Create application directory with restricted permissions
APP_DIR="$HOME/Library/Application Support/MinecraftScreentime"
mkdir -p "$APP_DIR"

# Download files
echo "Downloading necessary files..."
curl -sL "https://raw.githubusercontent.com/arohou/screentime/main/MinecraftScreentime.sh" > "$APP_DIR/MinecraftScreentime.sh"
curl -sL "https://raw.githubusercontent.com/arohou/screentime/main/SleepTime.sh" > "$APP_DIR/SleepTime.sh"
curl -sL "https://raw.githubusercontent.com/arohou/screentime/main/MinecraftScreentime.txt" > "$APP_DIR/MinecraftScreentime.txt"

# Make scripts executable but read-only
chmod 500 "$APP_DIR/MinecraftScreentime.sh"
chmod 500 "$APP_DIR/SleepTime.sh"
chmod 400 "$APP_DIR/MinecraftScreentime.txt"

# Create LaunchAgent for automatic running
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENT_DIR"

cat > "$LAUNCH_AGENT_DIR/com.minecraft.screentime.plist" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.minecraft.screentime</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${APP_DIR}/MinecraftScreentime.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOL

chmod 600 "$LAUNCH_AGENT_DIR/com.minecraft.screentime.plist"

# Load the LaunchAgent
launchctl load "$LAUNCH_AGENT_DIR/com.minecraft.screentime.plist"

# Request Full Disk Access using automation
echo "==============================================="
echo "IMPORTANT: Full Disk Access Setup Required"
echo "==============================================="
echo "System Settings will now open. Please follow these steps:"
echo "1. Click the '+' button"
echo "2. Press Command+Shift+G"
echo "3. Enter: /bin/bash"
echo "4. Click 'Open'"
echo ""
echo -n "Press Enter when you're ready to begin..."
read -r </dev/tty

# Open System Settings to the correct location
open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"

echo ""
echo "Please grant Full Disk Access permission to bash."
echo -n "Press Enter AFTER you have completed these steps..."
read -r </dev/tty

echo "==============================================="
echo "Testing permissions..."
echo "==============================================="
# Try to read a system file that requires Full Disk Access
if ! pmset -g log >/dev/null 2>&1; then
    echo "ERROR: Full Disk Access does not appear to be granted."
    echo "The script will not work correctly without this permission."
    echo "Please try the setup steps again."
    echo ""
    echo "Press Enter to continue anyway, or Ctrl+C to exit..."
    read -r </dev/tty
fi

# Now show the configuration instructions
echo ""
echo "==============================================="
echo "Installation complete!"
echo "==============================================="

echo ""
echo "IMPORTANT: Time Limit Configuration"
echo "------------------------------------"
echo "To set up remote management of time limits, the PARENT should:"
echo "1. On their own device (NOT this computer):"
echo "   - Open iCloud Drive"
echo "   - Create a new folder named 'MinecraftScreentimeConfig'"
echo "   - Create a file 'MinecraftScreentime.txt' with these contents:"
echo ""
echo "     WEEKDAY_LIMIT_MINUTES=60"
echo "     WEEKEND_LIMIT_MINUTES=120"
echo ""
echo "2. Share the folder with your child:"
echo "   - Right-click the folder"
echo "   - Select 'Share' → 'Collaborate'"
echo "   - Set permissions to 'Only invited people' and 'View only'"
echo "   - Share the invitation via Messages"
echo ""
echo "Current local time limits are:"
echo "Weekdays (Mon-Thu): $(grep WEEKDAY_LIMIT_MINUTES "$APP_DIR/MinecraftScreentime.txt" | cut -d= -f2) minutes"
echo "Weekends (Fri-Sun): $(grep WEEKEND_LIMIT_MINUTES "$APP_DIR/MinecraftScreentime.txt" | cut -d= -f2) minutes"
echo ""
echo "These limits will be overridden once you set up the shared iCloud configuration."
