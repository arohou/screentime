# screentime
Scripts to better manage screen time on macOS.

## MinecraftScreentime
This script runs every minute. 
It checks if Minecraft is running, and if it is, keeps track of how long it's been running. If Minecraft has run for more than the limit you set, it will kill the process and send a notification to the user. It will also send notifications when the user has a few minutes left.
There are two time limits - one for Monday-Thursday, the other for Friday-Sunday. Both can be specified in a configuration file, which you will create in a shared iCloud folder so that time limits can be changed remotely (from an iPhone, say).

## Installation

### Step 1: Install the Monitor
1. On your child's computer:
   - Open Terminal (press Command+Space and type "Terminal")
   - Copy and paste this command:
     ```bash
     curl -sL https://raw.githubusercontent.com/arohou/screentime/main/install.sh | bash
     ```
   - Follow the on-screen instructions when System Settings opens

### Step 2: Set Up Remote Management
For secure remote management, follow these steps on the PARENT'S device:

1. Create Two iCloud Folders:
   a. Configuration Folder (Read-Only):
      - Create folder `MinecraftScreentimeConfig`
      - Create file `MinecraftScreentime.txt` inside with:
        ```
        WEEKDAY_LIMIT_MINUTES=60
        WEEKEND_LIMIT_MINUTES=120
        ```
      - Share as read-only:
        - Right-click folder → Share → Collaborate
        - Set to "Only invited people" and "View only"
   
   b. Usage Logs Folder (Read-Write):
      - Create folder `MinecraftUsageLogs`
      - Share with read-write access:
        - Right-click folder → Share → Collaborate
        - Set to "Only invited people" and "Can make changes"

2. Share Both Folders:
   - Send invitations to your child via Messages
   - Ensure your child accepts both invitations
   - Verify the folders appear in their iCloud Drive


3. Verify Setup:
   - The folders should appear in your child's iCloud Drive
   - Your child should not be able to edit the configuration file
   - Changes you make from your device will automatically apply

### Changing Time Limits
As a parent, you can change time limits at any time:
1. On YOUR device, open the `MinecraftScreentime.txt` file in the shared folder
2. Edit the numbers as needed
3. Save the file
4. Changes will apply within one minute on your child's computer

### Monitoring Usage
You can monitor your child's Minecraft usage:
1. Open the `MinecraftUsageLogs` folder in iCloud Drive
2. Look for files named `username_YYYYMMDD.txt`
3. Each file contains:
   - Last update timestamp
   - Total play time for the day
   - Detailed session information

### Security Features
- Configuration can only be modified through the parent's shared folder
- Usage logs are stored in a separate shared folder with appropriate permissions
- Local configuration files are protected with restricted permissions
- Children cannot modify settings even with terminal access
- All scripts and configuration files are stored in secure system directories

### Troubleshooting

#### Running Diagnostics
To check if everything is set up correctly and diagnose any issues:

1. Download and run the diagnostics script:
   ```bash
   curl -sL https://raw.githubusercontent.com/arohou/screentime/main/run_diagnostics.sh | bash
   ```

2. The diagnostics tool will check:
   - Installation directory and file permissions
   - LaunchAgent configuration and status
   - Log files and recent entries
   - iCloud configuration
   - Full Disk Access permissions
   - Current time limits and settings

3. The output will show:
   - ✓ PASS in green for correctly configured components
   - ✗ FAIL in red for items that need attention
   - Recent log entries and current settings
   - Detailed information about any issues found

#### Checking Logs
- To monitor the script's activity, check the log file at `$HOME/Library/Application Support/minecraft/logs/screentime.log`

## Uninstallation

To remove Minecraft Screentime:

1. Download and run the uninstall script:
```bash
curl -sL https://raw.githubusercontent.com/arohou/screentime/main/uninstall.sh | bash
```

2. Optional cleanup steps:
   - Remove the shared configuration folder from the parent's iCloud Drive
   - Remove Full Disk Access permission for bash in System Settings if no longer needed
