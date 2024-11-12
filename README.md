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
For secure remote management of time limits, follow these steps on the PARENT'S device:

1. Create the Configuration Folder:
   - Open iCloud Drive on YOUR device (not your child's)
   - Create a new folder named `MinecraftScreentimeConfig`
   - Create a file `MinecraftScreentime.txt` inside this folder
   - Add these lines to set your desired limits:
     ```
     WEEKDAY_LIMIT_MINUTES=60
     WEEKEND_LIMIT_MINUTES=120
     ```

2. Share Securely with Your Child:
   - Right-click the folder
   - Select "Share" → "Collaborate"
   - Important: Set permissions to:
     - "Only invited people"
     - "View only" (this prevents your child from editing)
   - Share the invitation with your child (e.g., via Messages)

3. Verify Setup:
   - The folder should appear in your child's iCloud Drive
   - Your child should not be able to edit the file
   - Changes you make from your device will automatically apply

### Changing Time Limits
As a parent, you can change time limits at any time:
1. On YOUR device, open the `MinecraftScreentime.txt` file in the shared folder
2. Edit the numbers as needed
3. Save the file
4. Changes will apply within one minute on your child's computer

### Security Features
- Configuration can only be modified through the parent's shared folder
- Local configuration files are protected with restricted permissions
- Children cannot modify settings even with terminal access
- All scripts and configuration files are stored in secure system directories


## Uninstallation

To remove Minecraft Screentime:

1. Download and run the uninstall script:
```bash
curl -sL https://raw.githubusercontent.com/arohou/screentime/main/uninstall.sh | bash
```

2. Optional cleanup steps:
   - Remove the shared configuration folder from the parent's iCloud Drive
   - Remove Full Disk Access permission for bash in System Settings if no longer needed

