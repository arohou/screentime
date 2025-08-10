#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function for status output with troubleshooting suggestions
print_status() {
    local test_name="$1"
    local status="$2"
    local details="$3"
    local suggestions="$4"
    
    printf "${BLUE}Testing: %s${NC}\n" "$test_name"
    if [ "$status" = "PASS" ]; then
        printf "${GREEN}✓ PASS${NC}"
    else
        printf "${RED}✗ FAIL${NC}"
    fi
    echo " - $details"
    
    if [ "$status" = "FAIL" ] && [ -n "$suggestions" ]; then
        echo "  ${BLUE}Troubleshooting:${NC}"
        echo "  $suggestions"
    fi
    echo
}

# Function to extract directory paths from install.sh
extract_paths_from_install() {
    local install_script="$HOME/Library/Application Support/MinecraftScreentime/install.sh"
    if [ ! -f "$install_script" ]; then
        # Try to download install.sh if not found locally
        install_script=$(mktemp)
        curl -s "https://raw.githubusercontent.com/arohou/screentime/main/install.sh" > "$install_script"
    fi
    
    # Extract APP_DIR and LAUNCH_AGENT_DIR from install.sh
    APP_DIR=$(grep 'APP_DIR=' "$install_script" | head -1 | cut -d'=' -f2- | tr -d '"')
    LAUNCH_AGENT_DIR=$(grep 'LAUNCH_AGENT_DIR=' "$install_script" | head -1 | cut -d'=' -f2- | tr -d '"')
    
    # Evaluate the paths (replace $HOME with actual home directory)
    APP_DIR=$(eval echo "$APP_DIR")
    LAUNCH_AGENT_DIR=$(eval echo "$LAUNCH_AGENT_DIR")
}

# Function to extract MC_ROOT from MinecraftScreentime.sh
extract_mc_root() {
    local mc_script="$APP_DIR/MinecraftScreentime.sh"
    if [ ! -f "$mc_script" ]; then
        # Try to download MinecraftScreentime.sh if not found locally
        mc_script=$(mktemp)
        curl -s "https://raw.githubusercontent.com/arohou/screentime/main/MinecraftScreentime.sh" > "$mc_script"
    fi
    
    # Extract MC_ROOT from MinecraftScreentime.sh
    MC_ROOT=$(grep 'MC_ROOT=' "$mc_script" | head -1 | cut -d'=' -f2- | tr -d '"')
    # Evaluate the path (replace $HOME with actual home directory)
    MC_ROOT=$(eval echo "$MC_ROOT")
}

echo "Minecraft Screentime Diagnostic Tool"
echo "=================================="
echo

# Extract paths from original scripts
extract_paths_from_install
extract_mc_root

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

# Define iCloud paths
ICLOUD_BASE=$(detect_icloud_path)
if [ -n "$ICLOUD_BASE" ]; then
    CONFIG_DIR="$ICLOUD_BASE/MinecraftScreentimeConfig"
    USAGE_DIR="$ICLOUD_BASE/MinecraftUsageLogs"
else
    CONFIG_DIR=""
    USAGE_DIR=""
fi

# Verify that we got the paths
if [ -z "$APP_DIR" ] || [ -z "$LAUNCH_AGENT_DIR" ] || [ -z "$MC_ROOT" ]; then
    echo "${RED}ERROR: Failed to extract required paths from source scripts${NC}"
    echo "APP_DIR=${APP_DIR}"
    echo "LAUNCH_AGENT_DIR=${LAUNCH_AGENT_DIR}"
    echo "MC_ROOT=${MC_ROOT}"
    exit 1
fi

# Report iCloud Drive detection status
echo "System Configuration"
echo "==================="
if [ -n "$ICLOUD_BASE" ]; then
    echo "${GREEN}✓ iCloud Drive detected at: $ICLOUD_BASE${NC}"
else
    echo "${RED}⚠ iCloud Drive path not detected${NC}"
    echo "  ${BLUE}Possible causes:${NC}"
    echo "  • iCloud Drive is not enabled for this user"
    echo "  • User is not signed into iCloud"
    echo "  • iCloud Drive is using a non-standard path"
    echo "  • Permissions issue preventing access"
    echo ""
    echo "  ${BLUE}To check iCloud status:${NC}"
    echo "  • Open System Settings → Apple ID → iCloud"
    echo "  • Ensure iCloud Drive is enabled"
    echo "  • Check that you're signed in with the correct Apple ID"
fi
echo ""

# 1. Check if installation directory exists
test_name="Installation Directory"
if [ -d "$APP_DIR" ]; then
    print_status "$test_name" "PASS" "Directory exists at $APP_DIR"
else
    suggestions="Run the install script again: curl -sSL https://raw.githubusercontent.com/arohou/screentime/main/install.sh | bash"
    print_status "$test_name" "FAIL" "Directory not found at $APP_DIR" "$suggestions"
fi

# 2. Check script files existence and permissions
for script in "MinecraftScreentime.sh" "SleepTime.sh"; do
    test_name="Script File: $script"
    if [ -f "$APP_DIR/$script" ]; then
        perms=$(stat -f "%Sp" "$APP_DIR/$script")
        if [ "$perms" = "-r-x------" ]; then
            print_status "$test_name" "PASS" "File exists with correct permissions (500)"
        else
            suggestions="Fix permissions: chmod 500 \"$APP_DIR/$script\""
            print_status "$test_name" "FAIL" "File exists but has wrong permissions: $perms (should be 500)" "$suggestions"
        fi
    else
        suggestions="Re-run installation script to restore missing files"
        print_status "$test_name" "FAIL" "File not found" "$suggestions"
    fi
done

# 3. Check configuration file
test_name="Local Configuration File"
if [ -f "$APP_DIR/MinecraftScreentime.txt" ]; then
    perms=$(stat -f "%Sp" "$APP_DIR/MinecraftScreentime.txt")
    if [ "$perms" = "-r--------" ]; then
        print_status "$test_name" "PASS" "File exists with correct permissions (400)"
    else
        suggestions="Fix permissions: chmod 400 \"$APP_DIR/MinecraftScreentime.txt\""
        print_status "$test_name" "FAIL" "File exists but has wrong permissions: $perms (should be 400)" "$suggestions"
    fi
else
    suggestions="Create config file with: echo 'WEEKDAY_LIMIT_MINUTES=60\nWEEKEND_LIMIT_MINUTES=120' > \"$APP_DIR/MinecraftScreentime.txt\" && chmod 400 \"$APP_DIR/MinecraftScreentime.txt\""
    print_status "$test_name" "FAIL" "File not found" "$suggestions"
fi

# 4. Check LaunchAgent configuration
test_name="LaunchAgent Configuration"
LAUNCH_AGENT="$LAUNCH_AGENT_DIR/com.minecraft.screentime.plist"
if [ -f "$LAUNCH_AGENT" ]; then
    perms=$(stat -f "%Sp" "$LAUNCH_AGENT")
    if [ "$perms" = "-rw-------" ]; then
        print_status "$test_name" "PASS" "LaunchAgent exists with correct permissions (600)"
    else
        suggestions="Fix permissions: chmod 600 \"$LAUNCH_AGENT\""
        print_status "$test_name" "FAIL" "LaunchAgent exists but has wrong permissions: $perms (should be 600)" "$suggestions"
    fi
else
    suggestions="Re-run installation script to create LaunchAgent"
    print_status "$test_name" "FAIL" "LaunchAgent file not found" "$suggestions"
fi

# 5. Check if LaunchAgent is loaded
test_name="LaunchAgent Status"
if launchctl list | grep -q "com.minecraft.screentime"; then
    print_status "$test_name" "PASS" "LaunchAgent is loaded and running"
else
    suggestions="Load LaunchAgent: launchctl load \"$LAUNCH_AGENT\" (requires LaunchAgent file to exist first)"
    print_status "$test_name" "FAIL" "LaunchAgent is not loaded" "$suggestions"
fi

# 6. Check log directory and recent logs
test_name="Log Directory"
if [ -d "$MC_ROOT/logs" ]; then
    print_status "$test_name" "PASS" "Log directory exists"
else
    suggestions="Create log directory: mkdir -p \"$MC_ROOT/logs\""
    print_status "$test_name" "FAIL" "Log directory not found" "$suggestions"
fi

# 7. Check iCloud Configuration Directory
test_name="iCloud Configuration Directory"
if [ -z "$ICLOUD_BASE" ]; then
    print_status "$test_name" "SKIP" "iCloud Drive not detected - skipping iCloud configuration check"
elif [ -d "$CONFIG_DIR" ]; then
    print_status "$test_name" "PASS" "iCloud configuration directory exists at $CONFIG_DIR"
    
    # Check configuration file
    if [ -f "$CONFIG_DIR/MinecraftScreentime.txt" ]; then
        echo "Current limits in iCloud config:"
        grep -E "^(WEEKDAY|WEEKEND)_LIMIT_MINUTES=" "$CONFIG_DIR/MinecraftScreentime.txt" || echo "No limits found in file"
        echo
    else
        suggestions="Create config file in iCloud: mkdir -p \"$CONFIG_DIR\" && echo 'WEEKDAY_LIMIT_MINUTES=60\nWEEKEND_LIMIT_MINUTES=120' > \"$CONFIG_DIR/MinecraftScreentime.txt\""
        print_status "iCloud Configuration File" "FAIL" "Configuration file not found in iCloud directory" "$suggestions"
    fi
else
    suggestions="Create iCloud config directory: mkdir -p \"$CONFIG_DIR\" (Note: Parent must share this folder with child account)"
    print_status "$test_name" "FAIL" "iCloud configuration directory not found at $CONFIG_DIR" "$suggestions"
fi

# 8. Check iCloud Usage Logs Directory
test_name="iCloud Usage Logs Directory"
if [ -z "$ICLOUD_BASE" ]; then
    print_status "$test_name" "SKIP" "iCloud Drive not detected - skipping iCloud usage logs check"
elif [ -d "$USAGE_DIR" ]; then
    print_status "$test_name" "PASS" "iCloud usage logs directory exists at $USAGE_DIR"
    
    # Check for today's usage log
    TODAY=$(date +%Y%m%d)
    USERNAME=$(whoami)
    TODAY_LOG="$USAGE_DIR/usage_${USERNAME}_${TODAY}.txt"
    
    if [ -f "$TODAY_LOG" ]; then
        echo "Today's usage log content:"
        cat "$TODAY_LOG"
        echo
    else
        echo "No usage log found for today (this is normal if Minecraft hasn't been played today)"
        echo
    fi
    
    # Show recent usage logs
    echo "Recent usage logs:"
    ls -lt "$USAGE_DIR" 2>/dev/null | head -n 5 || echo "No usage logs found"
    echo
else
    suggestions="Create iCloud usage directory: mkdir -p \"$USAGE_DIR\" (Note: Parent should create this directory and share with child account)"
    print_status "$test_name" "FAIL" "iCloud usage logs directory not found at $USAGE_DIR" "$suggestions"
fi

# 9. Check iCloud directory permissions
test_name="iCloud Directory Permissions"
check_icloud_permissions() {
    local dir="$1"
    local expected_access="$2"
    
    if [ ! -d "$dir" ]; then
        return 2
    fi
    
    if [ "$expected_access" = "true" ]; then
        if [ -w "$dir" ]; then
            return 0
        fi
    else
        if [ ! -w "$dir" ]; then
            return 0
        fi
    fi
    return 1
}

# Check config directory (should be accessible - iCloud sharing handles read-only enforcement)
if [ -z "$ICLOUD_BASE" ]; then
    print_status "Config Directory Permissions" "SKIP" "iCloud Drive not detected - skipping permissions check"
elif check_icloud_permissions "$CONFIG_DIR" "true"; then
    print_status "Config Directory Permissions" "PASS" "Configuration directory is accessible (iCloud sharing handles access control)"
else
    suggestions="Check iCloud sharing permissions. Parent should share the MinecraftScreentimeConfig folder with child account with 'View only' permissions"
    print_status "Config Directory Permissions" "FAIL" "Configuration directory is not accessible" "$suggestions"
fi

# Check usage directory (should be writable)
if [ -z "$ICLOUD_BASE" ]; then
    print_status "Usage Directory Permissions" "SKIP" "iCloud Drive not detected - skipping permissions check"
elif check_icloud_permissions "$USAGE_DIR" "true"; then
    print_status "Usage Directory Permissions" "PASS" "Usage logs directory is writable as expected"
else
    suggestions="Check iCloud sharing permissions. Parent should share the MinecraftUsageLogs folder with child account with 'Can make changes' permissions"
    print_status "Usage Directory Permissions" "FAIL" "Usage logs directory has incorrect permissions" "$suggestions"
fi

# 10. Check Full Disk Access
test_name="Full Disk Access"
if pmset -g log >/dev/null 2>&1; then
    print_status "$test_name" "PASS" "Full Disk Access appears to be granted"
else
    suggestions="Grant Full Disk Access: Open System Settings → Privacy & Security → Full Disk Access → Click '+' → Navigate to /bin/bash and add it"
    print_status "$test_name" "FAIL" "Full Disk Access appears to be missing" "$suggestions"
fi

# Additional troubleshooting for managed child accounts
echo "==============================================="
echo "Special Considerations for Managed Child Accounts"
echo "==============================================="
echo "If this is a managed child account, additional steps may be needed:"
echo ""
echo -e "${BLUE}1. iCloud Drive Access:${NC}"
echo "   • Child accounts may have restricted iCloud Drive access"
echo "   • Parent must explicitly share folders with child account"
echo "   • Check Family Sharing settings in System Settings"
echo ""
echo -e "${BLUE}2. Permissions and Security:${NC}"
echo "   • Managed accounts may have additional restrictions"
echo "   • Parent may need to approve Full Disk Access requests"
echo "   • Some system directories may be read-only for child accounts"
echo ""
echo -e "${BLUE}3. LaunchAgent Loading:${NC}"
echo "   • Child accounts may require parent approval for background processes"
echo "   • Check Screen Time restrictions that might block background apps"
echo ""

# Display overall system status
echo "==============================================="
echo "Overall System Status"
echo "==============================================="
if [ -n "$ICLOUD_BASE" ]; then
    icloud_status="${GREEN}detected${NC}"
    config_check="$CONFIG_DIR/MinecraftScreentime.txt"
    usage_check="$USAGE_DIR"
else
    icloud_status="${RED}not detected${NC}"
    config_check=""
    usage_check=""
fi

echo -e "1. Basic installation appears to be $([ -d "$APP_DIR" ] && echo "${GREEN}complete${NC}" || echo "${RED}incomplete${NC}")"
echo -e "2. iCloud Drive is $icloud_status"
if [ -n "$config_check" ]; then
    echo -e "3. iCloud configuration is $([ -f "$config_check" ] && echo "${GREEN}set up${NC}" || echo "${RED}missing${NC}")"
    echo -e "4. Usage logging is $([ -d "$usage_check" ] && echo "${GREEN}enabled${NC}" || echo "${RED}not configured${NC}")"
else
    echo -e "3. iCloud configuration is ${RED}not available (iCloud not detected)${NC}"
    echo -e "4. Usage logging is ${RED}not available (iCloud not detected)${NC}"
fi
echo -e "5. Automated monitoring is $(launchctl list | grep -q "com.minecraft.screentime" && echo "${GREEN}running${NC}" || echo "${RED}stopped${NC}")"