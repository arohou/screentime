# screentime
Scripts to better manage screen time on macOS.

## MinecraftScreentime
This script is designed to be run as a cron job every minute on MacOS. 
It checks if Minecraft is running, and if it is, keeps track of how long it's been running. If it's been running for more than the limit you set, it will kill the process and send a notification to the user. It will also send a notification when the user has 5 minutes left, and every minute after that.
To install it:
1. Download the script and put it somewhere on your computer
- Open the Terminal application
- Navigate to a directory of your choice (e.g. `cd ~/Documents; mkdir git; cd git`)
- Enter the following command to clone the directory: `git clone https://github.com/arohou/screentime.git` (you may have to install the command line development tools first)
2. Open the script in a text editor and change the `SCEENTIME_LIMIT_MINUTES` variable to the number of minutes you want to allow Minecraft to run for each day.
3. Create a cron job to run the script every minute:
- Open the Terminal application
- Enter the following command: `crontab -e`
- If this is your first time using cron, you will be asked to choose a text editor. I recommend nano.
- Add the following line to the end of the file: `* * * * * /bin/bash /Users/<username>/Documents/git/screentime/MinecraftScreentime.sh`
- After saving the file, you may get a popup "Terminal would like to administer your computer...". Click Allow.
4. Grant cron full disk access:
- Open System Preferences
- Click Privacy & Security
- Click Full Disk Access
- Click the + icon
- Navigate to /usr/sbin/cron and click Open (hint: you may have to press Command+Shift+. to show hidden files)
