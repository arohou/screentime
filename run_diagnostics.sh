#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function for status output
print_status() {
    local test_name="$1"
    local status="$2"
    local details="$3"
    
    printf "${BLUE}Testing: %s${NC}\n" "$test_name"
    if [ "$status" = "PASS" ]; then
        printf "${GREEN}✓ PASS${NC}"
    else
        printf "${RED}✗ FAIL${NC}"
    fi
    echo " - $details"
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

# Define iCloud paths
ICLOUD_BASE="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
CONFIG_DIR="$ICLOUD_BASE/MinecraftScreentimeConfig"
USAGE_DIR="$ICLOUD_BASE/MinecraftUsageLogs"

# Verify that we got the paths
if [ -z "$APP_DIR" ] || [ -z "$LAUNCH_AGENT_DIR" ] || [ -z "$MC_ROOT" ]; then
    echo "${RED}ERROR: Failed to extract required paths from source scripts${NC}"
    echo "APP_DIR=${APP_DIR}"
    echo "LAUNCH_AGENT_DIR=${LAUNCH_AGENT_DIR}"
    echo "MC_ROOT=${MC_ROOT}"
    exit 1
fi

# 1. Check if installation directory exists
test_name="Installation Directory"
if [ -d "$APP_DIR" ]; then
    print_status "$test_name" "PASS" "Directory exists at $APP_DIR"
else
    print_status "$test_name" "FAIL" "Directory not found at $APP_DIR"
fi

# 2. Check script files existence and permissions
for script in "MinecraftScreentime.sh" "SleepTime.sh"; do
    test_name="Script File: $script"
    if [ -f "$APP_DIR/$script" ]; then
        perms=$(stat -f "%Sp" "$APP_DIR/$script")
        if [ "$perms" = "-r-x------" ]; then
            print_status "$test_name" "PASS" "File exists with correct permissions (500)"
        else
            print_status "$test_name" "FAIL" "File exists but has wrong permissions: $perms (should be 500)"
        fi
    else
        print_status "$test_name" "FAIL" "File not found"
    fi
done

# 3. Check configuration file
test_name="Local Configuration File"
if [ -f "$APP_DIR/MinecraftScreentime.txt" ]; then
    perms=$(stat -f "%Sp" "$APP_DIR/MinecraftScreentime.txt")
    if [ "$perms" = "-r--------" ]; then
        print_status "$test_name" "PASS" "File exists with correct permissions (400)"
    else
        print_status "$test_name" "FAIL" "File exists but has wrong permissions: $perms (should be 400)"
    fi
else
    print_status "$test_name" "FAIL" "File not found"
fi

# 4. Check LaunchAgent configuration
test_name="LaunchAgent Configuration"
LAUNCH_AGENT="$LAUNCH_AGENT_DIR/com.minecraft.screentime.plist"
if [ -f "$LAUNCH_AGENT" ]; then
    perms=$(stat -f "%Sp" "$LAUNCH_AGENT")
    if [ "$perms" = "-rw-------" ]; then
        print_status "$test_name" "PASS" "LaunchAgent exists with correct permissions (600)"
    else
        print_status "$test_name" "FAIL" "LaunchAgent exists but has wrong permissions: $perms (should be 600)"
    fi
else
    print_status "$test_name" "FAIL" "LaunchAgent file not found"
fi

# 5. Check if LaunchAgent is loaded
test_name="LaunchAgent Status"
if launchctl list | grep -q "com.minecraft.screentime"; then
    print_status "$test_name" "PASS" "LaunchAgent is loaded and running"
else
    print_status "$test_name" "FAIL" "LaunchAgent is not loaded"
fi

# 6. Check log directory and recent logs
test_name="Log Directory"
if [ -d "$MC_ROOT/logs" ]; then
    print_status "$test_name" "PASS" "Log directory exists"
else
    print_status "$test_name" "FAIL" "Log directory not found"
fi

# 7. Check iCloud Configuration Directory
test_name="iCloud Configuration Directory"
if [ -d "$CONFIG_DIR" ]; then
    print_status "$test_name" "PASS" "iCloud configuration directory exists"
    
    # Check configuration file
    if [ -f "$CONFIG_DIR/MinecraftScreentime.txt" ]; then
        echo "Current limits in iCloud config:"
        grep -E "^(WEEKDAY|WEEKEND)_LIMIT_MINUTES=" "$CONFIG_DIR/MinecraftScreentime.txt" || echo "No limits found in file"
        echo
    else
        print_status "iCloud Configuration File" "FAIL" "Configuration file not found in iCloud directory"
    fi
else
    print_status "$test_name" "FAIL" "iCloud configuration directory not found"
fi

# 8. Check iCloud Usage Logs Directory
test_name="iCloud Usage Logs Directory"
if [ -d "$USAGE_DIR" ]; then
    print_status "$test_name" "PASS" "iCloud usage logs directory exists"
    
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
    ls -lt "$USAGE_DIR" | head -n 5
    echo
else
    print_status "$test_name" "FAIL" "iCloud usage logs directory not found"
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
if check_icloud_permissions "$CONFIG_DIR" "true"; then
    print_status "Config Directory Permissions" "PASS" "Configuration directory is accessible (iCloud sharing handles access control)"
else
    print_status "Config Directory Permissions" "FAIL" "Configuration directory is not accessible"
fi

# Check usage directory (should be writable)
if check_icloud_permissions "$USAGE_DIR" "true"; then
    print_status "Usage Directory Permissions" "PASS" "Usage logs directory is writable as expected"
else
    print_status "Usage Directory Permissions" "FAIL" "Usage logs directory has incorrect permissions"
fi

# 10. Check Full Disk Access
test_name="Full Disk Access"
if pmset -g log >/dev/null 2>&1; then
    print_status "$test_name" "PASS" "Full Disk Access appears to be granted"
else
    print_status "$test_name" "FAIL" "Full Disk Access appears to be missing"
fi

# Display overall system status
echo "==============================================="
echo "Overall System Status"
echo "==============================================="
echo -e "1. Basic installation appears to be $([ -d "$APP_DIR" ] && echo "${GREEN}complete${NC}" || echo "${RED}incomplete${NC}")"
echo -e "2. iCloud configuration is $([ -f "$CONFIG_DIR/MinecraftScreentime.txt" ] && echo "${GREEN}set up${NC}" || echo "${RED}missing${NC}")"
echo -e "3. Usage logging is $([ -d "$USAGE_DIR" ] && echo "${GREEN}enabled${NC}" || echo "${RED}not configured${NC}")"
echo -e "4. Automated monitoring is $(launchctl list | grep -q "com.minecraft.screentime" && echo "${GREEN}running${NC}" || echo "${RED}stopped${NC}")"