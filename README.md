# screentime
Scripts to better manage screen time on macOS.

## MinecraftScreentime
This script is designed to be run as a cron job every minute on MacOS. 
It checks if Minecraft is running, and if it is, keeps track of how long it's been running. If it's been running for more than the limit you set, it will kill the process and send a notification to the user. It will also send notifications when the user has a few minutes left.
There are two time limits - one for Monday-Thursday, the other for Friday-Sunday. Both can be specified in a configuration file. For convenience, the configuration file can be in a shared iCloud folder so that time limits can be changed remotely (from an iPhone, say).

### Script installation
1. Download the script and put it somewhere on your computer
- Open the Terminal application
- Navigate to a directory of your choice (e.g. `cd ~/Documents; mkdir git; cd git`)
- Enter the following command to clone the directory: `git clone https://github.com/arohou/screentime.git` (you may have to install the command line development tools first)
2. Create a cron job to run the script every minute:
- Open the Terminal application
- Enter the following command: `crontab -e`
- If this is your first time using cron, you will be asked to choose a text editor. I recommend nano.
- Add the following line to the end of the file: `* * * * * /bin/bash /Users/<username>/Documents/git/screentime/MinecraftScreentime.sh`
- After saving the file, you may get a popup "Terminal would like to administer your computer...". Click Allow.
3. Grant cron full disk access:
- Open System Preferences
- Click Privacy & Security
- Click Full Disk Access
- Click the + icon
- Navigate to /usr/sbin/cron and click Open (hint: you may have to press Command+Shift+. to show hidden files)

### Time limit configuration
The script ships with a default configuration file, called `MinecraftScreentime.conf` and located in the same directory as the script. You can edit that file to specify your own time limits, in minutes.
For added convenience, the script will also look for a folder shared on iCloud called `MinecraftScreentimeConfig`. If this is found, and it contains a `MinecraftScreentime.conf` file, the time limits found in that file will take precedence.
#### Creating a shared configuration file on iCloud
On your (the parent's) device (preferably a laptop):
- In Finder (MacOS) or the Files app (iOS), navigate to iCloud Drive
- Create a new folder
  - iOS
    - Click on the three dots (top right of screen)
    - Tap "New Folder"
  - MacOS
    - Right-Click
    - New Folder
- Name the folder `MinecraftScreentimeConfig`
- Long tap (right click) on the folder, select Share
- Select "Collaborate"
- Tap on "Only invited people can edit" and change it to "Only invited people" and "View only" (that way your child will not be able to edit the time limit)
- Invite your child to "collaborate" on this folder (e.g. via Messages)
- Create a file `MinecraftScreentime.conf` within the folder, and add two lines to specify the limits (in minutes). Should look something like this:
```
WEEKDAY_LIMIT_MINUTES=60
WEEKEND_LIMIT_MINUTES=120
```
