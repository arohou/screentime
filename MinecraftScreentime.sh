#!/bin/bash -x
#
# This script will calculate the total time spent on Minecraft today
# and display notifications as a limit is approached. When the limit is
# reached, the script will kill the Minecraft process.
#
# This script is designed to be run as a cron job every minute.

#
# Edit the lines below
#

# Set the screentime limit in minutes
# This is the number of minutes that you want to allow your child to play Minecraft
# before Minecraft is automatically terminated.
# If you don't want to set a limit, set this to 0
SCEENTIME_LIMIT_MINUTES=60

# Where are the minecraft files installed?
MC_ROOT="$HOME/Library/Application Support/minecraft"


#
# You shouldn't need to edit anything beyond this point
#

# If the environment variable DEBUG is set, then enable debugging
if [ -n "$DEBUG" ]; then
    set -x
fi

# Convert screentime limit to seconds
SCEENTIME_LIMIT_SECONDS=$((SCEENTIME_LIMIT_MINUTES * 60))

# This script only works on MacOS. If on another OS, crash out with an error
if [ "$(uname)" != "Darwin" ]; then
    echo "This script only works on MacOS"
    exit 1
fi

# Find Minecraft screentime log files older than 7 days and delete them
find "$MC_ROOT/logs" -name "screentime_*.log" -mtime +7 -delete;

# Get today's date in the format yyyymmdd
TODAY=$(date +%Y%m%d)

# Set the path to the Minecraft screentime log file
# The format of the file is:
# one line per java process
# first word: PID of the java process
# second word: duration of the java process in seconds
MC_SCREENTIME_LOG="$MC_ROOT/logs/screentime_$TODAY.log"

# If the screentime log file doesn't exist, create it
if [ ! -f "$MC_SCREENTIME_LOG" ]; then
    touch "$MC_SCREENTIME_LOG"
fi


# Work out whether Minecraft is running, and if so save its PID
# We expect the game to be running in a java process with a name
# containing the word "minecraft"
MC_PID=$(ps aux | grep java | grep minecraft | head -1 | awk '{print $2}')

# If MC_PID has a value, then Minecraft is running
if [ -n "$MC_PID" ]; then
    # Get the duration that minecraft has been running (in seconds)
    # Credit: https://stackoverflow.com/a/28856613
    MC_RUNTIME=$(ps -p $MC_PID -oetime= | tr '-' ':' | awk -F: '{ total=0; m=1; } { for (i=0; i < NF; i++) {total += $(NF-i)*m; m *= i >= 2 ? 24 : 60 }} {print total}')

    # Does the screentime log file already contain a line for this java process?
    # If so, replace it; if not, append it
    if grep -q "^$MC_PID" "$MC_SCREENTIME_LOG"; then
        # Overwrite the corresponding line in the screentime log file (it has the first word as the PID)
        # with the new duration
        sed -i '' "s/^$MC_PID.*/$MC_PID $MC_RUNTIME/" "$MC_SCREENTIME_LOG"
    else
        # Append the PID and duration to the screentime log file
        echo "$MC_PID $MC_RUNTIME" >> "$MC_SCREENTIME_LOG"
    fi
fi


# If the screentime log file exists, get the total time spent on Minecraft today
# by adding the time spent on each java minecraft process
TOTAL_SCEENTIME=0
if [ -f "$MC_SCREENTIME_LOG" ]; then
    TOTAL_SCEENTIME=$(awk '{ sum += $2 } END { print sum }' "$MC_SCREENTIME_LOG")
fi

# If the screentime limit is greater than zero, and Minecraft is running, we may need to act
if [ "$SCEENTIME_LIMIT_SECONDS" -gt 0 ] && [ -n "$MC_PID" ]; then
    # Work out how many seconds are left
    SECONDS_LEFT=$(( SCEENTIME_LIMIT_SECONDS - TOTAL_SCEENTIME ))

    # If we are less than 5, but more than 1 minute away from the limit, display a notification
    if [ "$SECONDS_LEFT" -lt 300 ] && [ "$SECONDS_LEFT" -gt 60 ]; then
        # Work out how many minutes are left
        MINUTES_LEFT=$(( (SCEENTIME_LIMIT_SECONDS - TOTAL_SCEENTIME) / 60 ))
        # Is it 1 minute or more?
        plural=""
        if [ "$MINUTES_LEFT" -gt 1 ]; then
            plural="s"
        fi
        msg="Minecraft will be terminated in about $MINUTES_LEFT minute$plural"
        # Display a notification
        osascript -e "display dialog "$msg" buttons \"OK\" default button 1 with title \"Minecraft\" with icon caution"
    fi

    # If we are less than 1 minute away from the limit, wait until the limit 
    # has been reached, then kill the Minecraft process and display a notification
    if [ "$SECONDS_LEFT" -lt 60 ] && [ "$SECONDS_LEFT" -gt 0 ]; then
        # Wait until the limit has been reached
        sleep $SECONDS_LEFT
        # Kill the java process
        kill -9 $MC_PID
        # Show a popup to explain what happened
        osascript -e 'display dialog "Minecraft screentime limit exceeded; Minecraft has been terminated" buttons "OK" default button 1 with title "Minecraft" with icon caution' 
    fi

    # If the total screentime is greater than the limit, kill the Minecraft process
    # and display a notification
    if [ "$TOTAL_SCEENTIME" -gt "$SCEENTIME_LIMIT_SECONDS" ]; then
        # Kill the java process
        kill -9 $MC_PID
        # Show a popup to explain what happened
        osascript -e 'display dialog "Minecraft screentime limit exceeded; Minecraft has been terminated" buttons "OK" default button 1 with title "Minecraft" with icon caution' 
    fi
fi