#!/bin/bash
#
# This script will calculate the total time spent on Minecraft today
# and display notifications as a limit is approached. When the limit is
# reached, the script will kill the Minecraft process.
#
# This script is designed to be run as a cron job every minute.

# Enable debug mode only if DEBUG environment variable is set
if [ -n "$DEBUG" ]; then
    set -x
fi


#
# Configuration
#

# Default time limits (in minutes)
WEEKDAY_LIMIT_MINUTES=60   # Monday through Thursday
WEEKEND_LIMIT_MINUTES=120  # Friday through Sunday

# Define config file locations
SCRIPT_DIR="$(dirname "$0")"
LOCAL_CONFIG_FILE="$SCRIPT_DIR/MinecraftScreentime.txt"
SHARED_ICLOUD_CONFIG_FILE="$HOME/Library/Mobile Documents/com~apple~CloudDocs/MinecraftScreentimeConfig/MinecraftScreentime.txt"

# Other configurations
MC_ROOT="$HOME/Library/Application Support/minecraft"
NOTIFICATION_TIMES=(2 5 10)  # Show notifications at these minute marks
LOG_RETENTION_DAYS=7
GRACE_PERIOD_SECONDS=60     # 1 minute to save and exit
MIN_SESSION_LENGTH=60       # Ignore sessions shorter than 1 minute

# Create logs directory if it doesn't exist
mkdir -p "$MC_ROOT/logs"

# Log function
log() {
    local level="$1"
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$MC_ROOT/logs/screentime.log"
}


# Try to load config file from different locations in order of preference
for CONFIG_FILE in "$SHARED_ICLOUD_CONFIG_FILE" "$LOCAL_CONFIG_FILE"; do
    if [ -f "$CONFIG_FILE" ]; then
        log "INFO" "Loading configuration from: $CONFIG_FILE"
        # Source config file but only use known variables
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            # Remove any surrounding whitespace and quotes
            key=$(echo "$key" | tr -d ' ')
            value=$(echo "$value" | tr -d ' "'"'")
            
            # Add debug logging to track variable assignment
            log "DEBUG" "Setting $key=$value"
            
            case "$key" in
                "WEEKDAY_LIMIT_MINUTES") 
                    WEEKDAY_LIMIT_MINUTES=$value
                    log "DEBUG" "Updated weekday limit to: $WEEKDAY_LIMIT_MINUTES"
                    ;;
                "WEEKEND_LIMIT_MINUTES") 
                    WEEKEND_LIMIT_MINUTES=$value
                    log "DEBUG" "Updated weekend limit to: $WEEKEND_LIMIT_MINUTES"
                    ;;
            esac
        done < "$CONFIG_FILE"
        
        # Add verification logging after loading config
        log "INFO" "After loading config - Weekday limit: $WEEKDAY_LIMIT_MINUTES, Weekend limit: $WEEKEND_LIMIT_MINUTES"
        break
    fi
done



#
# Helper functions
#

display_notification() {
    local msg="$1"
    local icon="${2:-caution}"
    osascript -e "display dialog \"$msg\" buttons \"OK\" default button 1 with title \"Minecraft\" with icon $icon" &> /dev/null || true
}

get_active_runtime() {
    local pid="$1"
    local start_time="$2"
    
    # Get wall clock runtime
    local runtime=$(ps -p "$pid" -oetime= | tr '-' ':' | awk -F: '{ total=0; m=1; } { for (i=0; i < NF; i++) {total += $(NF-i)*m; m *= i >= 2 ? 24 : 60 }} {print total}')
    
    # Get sleep time
    local sleep_time=$(get_sleep_time_since "$start_time")
    local sleep_seconds=$(echo "$sleep_time" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
    
    # Calculate active runtime
    local active_time=$((runtime - sleep_seconds))
    echo "${active_time:-0}"
}

cleanup_old_logs() {
    find "$MC_ROOT/logs" -name "screentime_*.log" -mtime +"$LOG_RETENTION_DAYS" -delete
    find "$MC_ROOT/logs" -name "screentime.log" -mtime +"$LOG_RETENTION_DAYS" -delete
}

#
# Main script
#



# Import the get_sleep_time_since function
source "$(dirname "$0")/SleepTime.sh"

# Verify OS compatibility
if [ "$(uname)" != "Darwin" ]; then
    log "ERROR" "This script only works on MacOS"
    exit 1
fi

# Clean up old logs
cleanup_old_logs

# Determine today's limit based on the day of week
DAY_OF_WEEK=$(date +%u)
if [ "$DAY_OF_WEEK" -ge 5 ]; then
    SCREENTIME_LIMIT_MINUTES=$WEEKEND_LIMIT_MINUTES
    log "INFO" "Using weekend limit: $WEEKEND_LIMIT_MINUTES minutes"
else
    SCREENTIME_LIMIT_MINUTES=$WEEKDAY_LIMIT_MINUTES
    log "INFO" "Using weekday limit: $WEEKDAY_LIMIT_MINUTES minutes"
fi

SCREENTIME_LIMIT_SECONDS=$((SCREENTIME_LIMIT_MINUTES * 60))

# Setup today's log file
TODAY=$(date +%Y%m%d)
# Set the path to the Minecraft screentime log file
# The format of the file is:
# one line per java process
# first word: PID of the java process
# second word: duration of the java process in seconds
MC_SCREENTIME_LOG="$MC_ROOT/logs/screentime_$TODAY.log"
touch "$MC_SCREENTIME_LOG"

# Work out whether Minecraft is running, and if so save its PID
# We expect the game to be running in a java process with a name
# containing the word "minecraft"
MC_PID=$(pgrep -f "java.*minecraft" | head -1)

if [ -n "$MC_PID" ]; then
    # Get process start time
    PROCESS_START=$(ps -p "$MC_PID" -o lstart= | date -j -f "%a %b %d %T %Y" "$(cat -)" "+%Y-%m-%d %H:%M:%S")
    
    # Calculate active runtime
    MC_RUNTIME=$(get_active_runtime "$MC_PID" "$PROCESS_START")
    
    # Only log if the session is longer than minimum session length
    if [ "$MC_RUNTIME" -ge "$MIN_SESSION_LENGTH" ]; then
        # Update or append to the screentime log
        if grep -q "^$MC_PID" "$MC_SCREENTIME_LOG"; then
            # Overwrite the corresponding line in the screentime log file (it has the first word as the PID)
            # with the new duration
            sed -i '' "s/^$MC_PID.*/$MC_PID $MC_RUNTIME/" "$MC_SCREENTIME_LOG"
        else
            # Append the PID and duration to the screentime log file
            echo "$MC_PID $MC_RUNTIME" >> "$MC_SCREENTIME_LOG"
            log "INFO" "New Minecraft session started (PID: $MC_PID)"
        fi
    fi
    
    # Calculate total screentime
    # If the screentime log file exists, get the total time spent on Minecraft today
    # by adding the time spent on each java minecraft process
    TOTAL_SCREENTIME=0
    if [ -f "$MC_SCREENTIME_LOG" ]; then
        TOTAL_SCREENTIME=$(awk '{ sum += $2 } END { print sum }' "$MC_SCREENTIME_LOG")
    fi
    # If the screentime limit is greater than zero, and Minecraft is running, we may need to act
    if [ "$SCREENTIME_LIMIT_SECONDS" -gt 0 ]; then
        SECONDS_LEFT=$((SCREENTIME_LIMIT_SECONDS - TOTAL_SCREENTIME))
        
        # Check for notification thresholds
        for minutes in "${NOTIFICATION_TIMES[@]}"; do
            seconds=$((minutes * 60))
            if [ "$SECONDS_LEFT" -le "$seconds" ] && [ "$SECONDS_LEFT" -gt $((seconds - 60)) ]; then
                plural=""
                [ "$minutes" -gt 1 ] && plural="s"
                display_notification "Minecraft will be terminated in $minutes minute$plural"
                log "INFO" "Displayed $minutes minute warning"
                break
            fi
        done
        
        # Handle grace period and termination
        if [ "$SECONDS_LEFT" -le 0 ]; then
            if [ "$SECONDS_LEFT" -ge $((-GRACE_PERIOD_SECONDS)) ]; then
                display_notification "Minecraft screentime limit reached. Please save and exit within $((GRACE_PERIOD_SECONDS / 60)) minutes."
                log "WARNING" "Grace period started for PID $MC_PID"
            else
                kill -15 "$MC_PID"  # Try graceful termination first
                sleep 5
                if kill -0 "$MC_PID" 2>/dev/null; then
                    kill -9 "$MC_PID"  # Force kill if still running
                fi
                display_notification "Minecraft screentime limit exceeded; Minecraft has been terminated"
                log "INFO" "Terminated Minecraft process $MC_PID due to exceeded limit"
            fi
        fi
    fi
fi