#!/bin/bash

get_sleep_time_since() {
    local start_date="$1"
    
    if [ -z "$start_date" ]; then
        echo "Error: No date provided. Please use: YYYY-MM-DD HH:MM:SS" >&2
        return 1
    fi
    
    # Convert input date to Unix timestamp, considering timezone
    local start_timestamp=$(date -j -f "%Y-%m-%d %H:%M:%S" "$start_date" "+%s" 2>/dev/null)
    
    if [ -z "$start_timestamp" ]; then
        echo "Error: Invalid date format. Please use: YYYY-MM-DD HH:MM:SS" >&2
        return 1
    fi
    
    # Get sleep/wake events
    local sleep_data=$(pmset -g log | grep -E "Sleep.*Entering Sleep|Wake.*due to" | tail -n 1000 || true)
    
    if [ -z "$sleep_data" ]; then
        echo "00:00:00"
        return 0
    fi
    
    local total_sleep_seconds=0
    local sleep_start=""
    local MIN_SLEEP_DURATION=30  # Ignore sleep periods shorter than 30 seconds
    
    while IFS= read -r line; do
        # Extract timestamp, handling timezone
        local raw_timestamp=$(echo "$line" | cut -d' ' -f1-3)
        [ -z "$raw_timestamp" ] && continue
        
        # Convert timestamp with timezone to Unix time
        local unix_time=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$raw_timestamp" "+%s" 2>/dev/null)
        [ -z "$unix_time" ] && continue
        [ "$unix_time" -le "$start_timestamp" ] && continue
        
        if [[ $line =~ "Entering Sleep" ]]; then
            # Only start a new sleep period if we don't have one in progress
            if [ -z "$sleep_start" ]; then
                sleep_start=$unix_time
            fi
        elif [[ $line =~ "Wake" && -n "$sleep_start" ]]; then
            local sleep_duration=$((unix_time - sleep_start))
            if [ $sleep_duration -ge $MIN_SLEEP_DURATION ]; then
                total_sleep_seconds=$((total_sleep_seconds + sleep_duration))
            fi
            sleep_start=""
        fi
    done <<< "$sleep_data"
    
    # Convert seconds to hours:minutes:seconds
    local hours=$((total_sleep_seconds / 3600))
    local minutes=$(((total_sleep_seconds % 3600) / 60))
    local seconds=$((total_sleep_seconds % 60))
    
    printf "%02d:%02d:%02d\n" $hours $minutes $seconds
}

# Test function
test_sleep_time() {
    echo "Testing sleep time calculation..."
    
    # Test 1: Invalid date format
    echo "Test 1: Invalid date format"
    result=$(get_sleep_time_since "invalid-date")
    status=$?
    if [ $status -eq 1 ]; then
        echo "✅ Test 1 passed: Invalid date handled correctly"
    else
        echo "❌ Test 1 failed: Invalid date not caught (status: $status, result: $result)"
    fi
    
    # Test 2: Future date
    echo "Test 2: Future date"
    future_date=$(date -v+1d "+%Y-%m-%d %H:%M:%S")
    result=$(get_sleep_time_since "$future_date")
    if [ "$result" = "00:00:00" ]; then
        echo "✅ Test 2 passed: Future date returns zero sleep time"
    else
        echo "❌ Test 2 failed: Future date handling incorrect (got: $result)"
    fi
    
    # Test 3: Recent date
    echo "Test 3: Recent date (last 24 hours)"
    yesterday=$(date -v-24H "+%Y-%m-%d %H:%M:%S")
    result=$(get_sleep_time_since "$yesterday")
    status=$?
    if [ $status -eq 0 ]; then
        echo "Sleep time in last 24 hours: $result"
        echo "✅ Test 3 passed: Successfully calculated recent sleep time"
    else
        echo "❌ Test 3 failed: Error calculating recent sleep time (status: $status)"
    fi
}

# Run the tests
#test_sleep_time
