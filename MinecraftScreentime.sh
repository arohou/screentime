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

# Function to detect iCloud Drive path dynamically
detect_icloud_path() {
    local icloud_candidates=(
        "$HOME/Library/Mobile Documents/com~apple~CloudDocs"
        "$HOME/Library/Mobile Documents/iCloud~com~apple~CloudDocs"
        "$HOME/Mobile Documents/com~apple~CloudDocs"
    )
    
    for path in "${icloud_candidates[@]}"; do
        if [ -d "$path" ] && [ -w "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # If no standard path works, try to find it using mdfind
    local found_path
    found_path=$(mdfind "kMDItemDisplayName == 'com~apple~CloudDocs'" 2>/dev/null | head -1)
    if [ -n "$found_path" ] && [ -d "$found_path" ] && [ -w "$found_path" ]; then
        echo "$found_path"
        return 0
    fi
    
    # Return empty string if no valid iCloud path found
    echo ""
    return 1
}

# Define config file locations
SCRIPT_DIR="$(dirname "$0")"
LOCAL_CONFIG_FILE="$SCRIPT_DIR/MinecraftScreentime.txt"

# Detect iCloud Drive path dynamically
SHARED_ICLOUD_BASE=$(detect_icloud_path)
if [ -n "$SHARED_ICLOUD_BASE" ]; then
    SHARED_ICLOUD_CONFIG_DIR="$SHARED_ICLOUD_BASE/MinecraftScreentimeConfig"
    SHARED_ICLOUD_CONFIG_FILE="$SHARED_ICLOUD_CONFIG_DIR/MinecraftScreentime.txt"
    SHARED_ICLOUD_USAGE_DIR="$SHARED_ICLOUD_BASE/MinecraftUsageLogs"
    log "INFO" "Using iCloud Drive path: $SHARED_ICLOUD_BASE"
else
    SHARED_ICLOUD_CONFIG_DIR=""
    SHARED_ICLOUD_CONFIG_FILE=""
    SHARED_ICLOUD_USAGE_DIR=""
    log "WARNING" "iCloud Drive path not found - iCloud features will be disabled"
fi

# Define iCloud usage log location
USERNAME=$(whoami)
TODAY=$(date +%Y%m%d)
if [ -n "$SHARED_ICLOUD_USAGE_DIR" ]; then
    ICLOUD_USAGE_LOG="$SHARED_ICLOUD_USAGE_DIR/usage_${USERNAME}_${TODAY}.txt"
else
    ICLOUD_USAGE_LOG=""
fi

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

# Function to update iCloud usage log
update_icloud_usage() {
    local total_time="$1"
    local using_icloud="$2"
    
    if [ "$using_icloud" = "true" ] && [ -n "$SHARED_ICLOUD_USAGE_DIR" ]; then
        # Ensure usage directory exists
        mkdir -p "$SHARED_ICLOUD_USAGE_DIR"
        
        # Convert seconds to hours and minutes
        local hours=$((total_time / 3600))
        local minutes=$(((total_time % 3600) / 60))
        local last_update=$(date +'%Y-%m-%d %H:%M:%S')
        
        # Create or update the usage log file
        cat > "$ICLOUD_USAGE_LOG" << EOL
Last Updated: $last_update
Total Play Time: ${hours}h ${minutes}m
Total Seconds: $total_time
EOL
        
        log "INFO" "Updated iCloud usage log: ${hours}h ${minutes}m"
    fi
}

# Function to clean up old logs
cleanup_old_logs() {
    # Clean up local logs
    find "$MC_ROOT/logs" -name "screentime_*.log" -mtime +"$LOG_RETENTION_DAYS" -delete
    find "$MC_ROOT/logs" -name "screentime.log" -mtime +"$LOG_RETENTION_DAYS" -delete
    
    # Clean up iCloud logs if the directory exists
    if [ -d "$SHARED_ICLOUD_USAGE_DIR" ]; then
        # Find and delete old usage logs
        find "$SHARED_ICLOUD_USAGE_DIR" -name "usage_${USERNAME}_*.txt" -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null
        log "INFO" "Cleaned up old iCloud usage logs"
    fi
}

# Try to load config file from different locations in order of preference
USING_ICLOUD=false
CONFIG_FILES=("$LOCAL_CONFIG_FILE")
if [ -n "$SHARED_ICLOUD_CONFIG_FILE" ]; then
    CONFIG_FILES=("$SHARED_ICLOUD_CONFIG_FILE" "$LOCAL_CONFIG_FILE")
fi

for CONFIG_FILE in "${CONFIG_FILES[@]}"; do
    if [ -f "$CONFIG_FILE" ]; then
        log "INFO" "Loading configuration from: $CONFIG_FILE"
        [ "$CONFIG_FILE" = "$SHARED_ICLOUD_CONFIG_FILE" ] && USING_ICLOUD=true
        
        # Read file into variable first (handles missing newline at EOF)
        config_content=$(<"$CONFIG_FILE")
        
        # Process each line, using here-string to handle missing newline
        while IFS='=' read -r key value || [ -n "$key" ]; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            # Remove any surrounding whitespace, quotes, and CR characters
            key=$(echo "$key" | tr -d ' \r')
            value=$(echo "$value" | tr -d ' \r')
            
            # Skip if either key or value is empty after cleanup
            [[ -z "$key" || -z "$value" ]] && continue
            
            # Validate that value is a positive integer
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                log "WARNING" "Invalid value for $key: $value (must be a positive integer)"
                continue
            fi
            
            case "$key" in
                "WEEKDAY_LIMIT_MINUTES") 
                    WEEKDAY_LIMIT_MINUTES=$value
                    ;;
                "WEEKEND_LIMIT_MINUTES") 
                    WEEKEND_LIMIT_MINUTES=$value
                    ;;
                *)
                    log "WARNING" "Unknown configuration key: $key"
                    ;;
            esac
        done <<< "$config_content"
        
        break
    fi
done

# Helper functions
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

    # Update iCloud usage log if using iCloud configuration
    update_icloud_usage "$TOTAL_SCREENTIME" "$USING_ICLOUD"
    
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