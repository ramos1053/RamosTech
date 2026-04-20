#!/bin/bash

################################################################################
# Time Machine Manager
# Version: 2.1
# Compatible with: macOS 14+
# Description: Professional GUI for managing Time Machine snapshots
# Features: Snapshot management, detailed info, clean interface
################################################################################

set -euo pipefail  # Strict error handling
IFS=$'\n\t'

# Configuration
readonly SCRIPT_NAME="Time Machine Manager"
readonly SCRIPT_VERSION="2.1"
readonly TEMP_DIR="/tmp/tm_manager_$$"
readonly LOG_FILE="$TEMP_DIR/tm_manager.log"

# Color codes for terminal output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

################################################################################
# Utility Functions
################################################################################

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    if [[ "$level" == "ERROR" ]]; then
        echo -e "${RED}ERROR: $message${NC}" >&2
    elif [[ "$level" == "WARN" ]]; then
        echo -e "${YELLOW}WARNING: $message${NC}" >&2
    elif [[ "$level" == "INFO" ]]; then
        echo -e "${GREEN}INFO: $message${NC}"
    fi
}

# Initialize temp directory and cleanup handler
init() {
    mkdir -p "$TEMP_DIR" 2>/dev/null || {
        echo "Failed to create temp directory" >&2
        exit 1
    }
    log "INFO" "Initializing $SCRIPT_NAME v$SCRIPT_VERSION"
}

# Cleanup function
cleanup() {
    log "INFO" "Cleaning up temporary files"
    rm -rf "$TEMP_DIR" 2>/dev/null
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Check if running on macOS
check_os() {
    if [[ "$(uname)" != "Darwin" ]]; then
        log "ERROR" "This script requires macOS"
        exit 1
    fi
}

# Check for required commands
check_dependencies() {
    local deps=("tmutil" "diskutil" "osascript")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log "ERROR" "Required command not found: $cmd"
            exit 1
        fi
    done
}

################################################################################
# Time Machine Functions
################################################################################

# Get all snapshots with detailed information
get_snapshot_list() {
    local snapshots
    snapshots=$(tmutil listlocalsnapshots / 2>/dev/null | grep "com.apple.TimeMachine" || echo "")
    
    if [[ -z "$snapshots" ]]; then
        log "INFO" "No snapshots found"
        echo ""
        return
    fi
    
    log "INFO" "Found $(echo "$snapshots" | wc -l | tr -d ' ') snapshots"
    
    # Format snapshots for display with enhanced info
    echo "$snapshots" | while IFS= read -r snapshot; do
        local date_part=$(echo "$snapshot" | sed 's/com.apple.TimeMachine.//')
        
        # Convert to readable format: 2024-01-15-120000 -> 2024-01-15 12:00:00
        local year=${date_part:0:4}
        local month=${date_part:5:2}
        local day=${date_part:8:2}
        local hour=${date_part:11:2}
        local minute=${date_part:13:2}
        local second=${date_part:15:2}
        
        local formatted_date="$year-$month-$day $hour:$minute:$second"
        
        # Calculate how old the snapshot is
        local snapshot_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$formatted_date" "+%s" 2>/dev/null || echo "0")
        local current_epoch=$(date "+%s")
        local age_seconds=$((current_epoch - snapshot_epoch))
        local age_hours=$((age_seconds / 3600))
        local age_days=$((age_hours / 24))
        
        local age_display=""
        if [[ $age_days -gt 0 ]]; then
            age_display="($age_days days old)"
        elif [[ $age_hours -gt 0 ]]; then
            age_display="($age_hours hours old)"
        else
            age_display="(recent)"
        fi
        
        echo "$snapshot|$formatted_date $age_display"
    done
}

# Get Time Machine status with detailed info
get_tm_status() {
    local status_output
    status_output=$(tmutil status 2>/dev/null || echo "")
    
    if echo "$status_output" | grep -q "Running = 1"; then
        echo "Running"
    elif echo "$status_output" | grep -q "AutoBackup = 1"; then
        echo "Enabled"
    else
        echo "Disabled"
    fi
}

# Get detailed destination information
get_destination_info() {
    local dest_info
    dest_info=$(tmutil destinationinfo 2>/dev/null || echo "")
    
    if [[ -z "$dest_info" ]]; then
        echo "None configured"
        return
    fi
    
    local dest_name=$(echo "$dest_info" | grep "Name" | head -1 | awk '{$1=""; print $0}' | xargs)
    local dest_kind=$(echo "$dest_info" | grep "Kind" | head -1 | awk '{$1=""; print $0}' | xargs)
    local dest_id=$(echo "$dest_info" | grep "^ID" | head -1 | awk '{print $NF}')
    
    if [[ -n "$dest_name" ]]; then
        echo "$dest_name${dest_kind:+ ($dest_kind)}"
    else
        echo "Configured (ID: ${dest_id:-unknown})"
    fi
}

# Get system disk space information
get_disk_space() {
    local disk_info=$(df -h / | tail -1)
    local total=$(echo "$disk_info" | awk '{print $2}')
    local used=$(echo "$disk_info" | awk '{print $3}')
    local available=$(echo "$disk_info" | awk '{print $4}')
    local percent=$(echo "$disk_info" | awk '{print $5}')
    
    echo "Total: $total | Used: $used | Available: $available ($percent full)"
}

# Estimate snapshot sizes
estimate_snapshot_size() {
    local snapshot_count=$1
    
    if [[ $snapshot_count -eq 0 ]]; then
        echo "0 GB"
        return
    fi
    
    # Estimate: typically 2-8GB per snapshot, using 4GB average
    local estimate=$((snapshot_count * 4))
    
    if [[ $estimate -lt 1 ]]; then
        echo "< 1 GB"
    else
        echo "~${estimate} GB"
    fi
}

# Get comprehensive snapshot details
get_detailed_snapshot_info() {
    local snapshot=$1
    local date_part=$(echo "$snapshot" | sed 's/com.apple.TimeMachine.//')
    
    # Parse date components
    local year=${date_part:0:4}
    local month=${date_part:5:2}
    local day=${date_part:8:2}
    local hour=${date_part:11:2}
    local minute=${date_part:13:2}
    local second=${date_part:15:2}
    
    local formatted_date="$year-$month-$day $hour:$minute:$second"
    
    # Get destination info
    local dest_info=$(tmutil destinationinfo 2>/dev/null || echo "")
    local dest_name="Not available"
    local dest_mount="Not available"
    
    if [[ -n "$dest_info" ]]; then
        dest_name=$(echo "$dest_info" | grep "Name" | head -1 | awk '{$1=""; print $0}' | xargs)
        dest_mount=$(echo "$dest_info" | grep "Mount Point" | head -1 | awk '{$1=$2=""; print $0}' | xargs)
        [[ -z "$dest_name" ]] && dest_name="Configured"
        [[ -z "$dest_mount" ]] && dest_mount="Not mounted"
    fi
    
    # Get latest backup info
    local latest_backup=$(tmutil latestbackup 2>/dev/null || echo "Unknown")
    local backup_date="Unknown"
    
    if [[ "$latest_backup" != "Unknown" ]] && [[ -n "$latest_backup" ]]; then
        # Extract date from backup path if available
        backup_date=$(echo "$latest_backup" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}' | head -1)
        if [[ -n "$backup_date" ]]; then
            # Format it nicely
            local b_year=${backup_date:0:4}
            local b_month=${backup_date:5:2}
            local b_day=${backup_date:8:2}
            local b_hour=${backup_date:11:2}
            local b_minute=${backup_date:13:2}
            local b_second=${backup_date:15:2}
            backup_date="$b_year-$b_month-$b_day $b_hour:$b_minute:$b_second"
        fi
    fi
    
    # Calculate age
    local snapshot_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$formatted_date" "+%s" 2>/dev/null || echo "0")
    local current_epoch=$(date "+%s")
    local age_seconds=$((current_epoch - snapshot_epoch))
    local age_days=$((age_seconds / 86400))
    local age_hours=$(((age_seconds % 86400) / 3600))
    local age_minutes=$(((age_seconds % 3600) / 60))
    
    local age_display=""
    if [[ $age_days -gt 0 ]]; then
        age_display="$age_days days, $age_hours hours"
    elif [[ $age_hours -gt 0 ]]; then
        age_display="$age_hours hours, $age_minutes minutes"
    else
        age_display="$age_minutes minutes"
    fi
    
    # Get APFS info
    local apfs_info=$(diskutil apfs listSnapshots / 2>/dev/null | grep -B2 -A8 "$date_part" 2>/dev/null || echo "")
    local apfs_display="Not available"
    if [[ -n "$apfs_info" ]]; then
        apfs_display=$(echo "$apfs_info" | head -10)
    fi
    
    # Get total snapshot count
    local total_snapshots=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c "com.apple.TimeMachine" || echo "0")
    
    # Build output
    cat << DETAILS
SNAPSHOT DETAILS

Name:
$snapshot

Created:
$formatted_date

Age:
$age_display old

Location:
/ (Root Volume)

Backup Destination:
Name: $dest_name
Mount: $dest_mount

Latest Backup:
$backup_date

Total Snapshots:
$total_snapshots on this system

APFS Information:
$apfs_display

Disk Space:
$(get_disk_space)
DETAILS
}

################################################################################
# GUI Functions
################################################################################

# Create the helper script for detail retrieval
create_helper_script() {
    local helper_script="$TEMP_DIR/helper.sh"
    
    # Export functions to helper script
    cat > "$helper_script" << 'HELPER_EOF'
#!/bin/bash

get_detailed_snapshot_info() {
    local snapshot=$1
    local date_part=$(echo "$snapshot" | sed 's/com.apple.TimeMachine.//')
    
    # Parse date components
    local year=${date_part:0:4}
    local month=${date_part:5:2}
    local day=${date_part:8:2}
    local hour=${date_part:11:2}
    local minute=${date_part:13:2}
    local second=${date_part:15:2}
    
    local formatted_date="$year-$month-$day $hour:$minute:$second"
    
    # Get destination info
    local dest_info=$(tmutil destinationinfo 2>/dev/null || echo "")
    local dest_name="Not available"
    local dest_mount="Not available"
    
    if [[ -n "$dest_info" ]]; then
        dest_name=$(echo "$dest_info" | grep "Name" | head -1 | awk '{$1=""; print $0}' | xargs)
        dest_mount=$(echo "$dest_info" | grep "Mount Point" | head -1 | awk '{$1=$2=""; print $0}' | xargs)
        [[ -z "$dest_name" ]] && dest_name="Configured"
        [[ -z "$dest_mount" ]] && dest_mount="Not mounted"
    fi
    
    # Get latest backup info
    local latest_backup=$(tmutil latestbackup 2>/dev/null || echo "Unknown")
    local backup_date="Unknown"
    
    if [[ "$latest_backup" != "Unknown" ]] && [[ -n "$latest_backup" ]]; then
        backup_date=$(echo "$latest_backup" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}' | head -1)
        if [[ -n "$backup_date" ]]; then
            local b_year=${backup_date:0:4}
            local b_month=${backup_date:5:2}
            local b_day=${backup_date:8:2}
            local b_hour=${backup_date:11:2}
            local b_minute=${backup_date:13:2}
            local b_second=${backup_date:15:2}
            backup_date="$b_year-$b_month-$b_day $b_hour:$b_minute:$b_second"
        fi
    fi
    
    # Calculate age
    local snapshot_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$formatted_date" "+%s" 2>/dev/null || echo "0")
    local current_epoch=$(date "+%s")
    local age_seconds=$((current_epoch - snapshot_epoch))
    local age_days=$((age_seconds / 86400))
    local age_hours=$(((age_seconds % 86400) / 3600))
    local age_minutes=$(((age_seconds % 3600) / 60))
    
    local age_display=""
    if [[ $age_days -gt 0 ]]; then
        age_display="$age_days days, $age_hours hours"
    elif [[ $age_hours -gt 0 ]]; then
        age_display="$age_hours hours, $age_minutes minutes"
    else
        age_display="$age_minutes minutes"
    fi
    
    # Get APFS info
    local apfs_info=$(diskutil apfs listSnapshots / 2>/dev/null | grep -B2 -A8 "$date_part" 2>/dev/null || echo "")
    local apfs_display="Not available"
    if [[ -n "$apfs_info" ]]; then
        apfs_display=$(echo "$apfs_info" | head -10)
    fi
    
    # Get total snapshots
    local total_snapshots=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c "com.apple.TimeMachine" || echo "0")
    
    # Get disk space
    local disk_info=$(df -h / | tail -1)
    local total=$(echo "$disk_info" | awk '{print $2}')
    local used=$(echo "$disk_info" | awk '{print $3}')
    local available=$(echo "$disk_info" | awk '{print $4}')
    local percent=$(echo "$disk_info" | awk '{print $5}')
    local disk_space="Total: $total | Used: $used | Available: $available ($percent full)"
    
    # Build output
    cat << DETAILS
SNAPSHOT DETAILS

Name:
$snapshot

Created:
$formatted_date

Age:
$age_display old

Location:
/ (Root Volume)

Backup Destination:
Name: $dest_name
Mount: $dest_mount

Latest Backup:
$backup_date

Total Snapshots:
$total_snapshots on this system

APFS Information:
$apfs_display

Disk Space:
$disk_space
DETAILS
}

if [[ -n "$1" ]]; then
    get_detailed_snapshot_info "$1"
else
    echo "Error: No snapshot specified"
    exit 1
fi
HELPER_EOF
    
    chmod +x "$helper_script"
    echo "$helper_script"
}

# Main GUI application
main_gui() {
    log "INFO" "Launching GUI"
    
    # Get current system state
    local snapshot_data=$(get_snapshot_list)
    local tm_status=$(get_tm_status)
    local dest_info=$(get_destination_info)
    local disk_space=$(get_disk_space)
    local snapshot_count=0
    
    if [[ -n "$snapshot_data" ]]; then
        snapshot_count=$(echo "$snapshot_data" | wc -l | tr -d ' ')
    fi
    
    local size_estimate=$(estimate_snapshot_size "$snapshot_count")
    
    # Prepare snapshot list for display
    local snapshot_list=""
    if [[ -n "$snapshot_data" ]]; then
        snapshot_list=$(echo "$snapshot_data" | awk -F'|' '{print $2}')
    else
        snapshot_list="No snapshots found"
    fi
    
    # Convert to AppleScript array format
    local as_list=""
    if [[ $snapshot_count -gt 0 ]]; then
        while IFS= read -r line; do
            # Escape quotes and special characters
            line=$(echo "$line" | sed "s/'/\\\\'/g")
            as_list+="\"$line\", "
        done <<< "$snapshot_list"
        as_list=${as_list%, }
    else
        as_list="\"No snapshots found\""
    fi
    
    # Save snapshot data
    local temp_data="$TEMP_DIR/snapshot_data.txt"
    echo "$snapshot_data" > "$temp_data"
    
    # Create helper script
    local helper_script=$(create_helper_script)
    
    log "INFO" "Displaying GUI with $snapshot_count snapshots"
    
    # Launch AppleScript GUI
    osascript <<EOF
-- Time Machine Manager - Main Interface

set snapshotList to {$as_list}
set tmStatus to "$tm_status"
set destInfo to "$dest_info"
set snapshotCount to $snapshot_count
set sizeEstimate to "$size_estimate"
set diskSpace to "$disk_space"
set tempData to "$temp_data"
set helperScript to "$helper_script"
set scriptVersion to "$SCRIPT_VERSION"

-- Main dialog loop
repeat
    try
        -- Build header
        set headerText to "TIME MACHINE MANAGER v" & scriptVersion & return & return
        headerText = headerText & "Status: " & tmStatus & return
        headerText = headerText & "Snapshots: " & snapshotCount & " (" & sizeEstimate & ")" & return
        headerText = headerText & "Destination: " & destInfo & return
        headerText = headerText & diskSpace & return & return
        headerText = headerText & "Select a snapshot to manage:"
        
        set dialogResult to choose from list snapshotList with prompt headerText with title "Time Machine Manager" OK button name "Manage" cancel button name "Exit" with empty selection allowed default items {}
        
        if dialogResult is false then
            exit repeat
        end if
        
        if dialogResult is {} then
            display alert "No Selection" message "Please select a snapshot from the list." as informational
        else
            set selectedSnapshot to item 1 of dialogResult
            
            if selectedSnapshot is "No snapshots found" then
                display alert "No Snapshots" message "No Time Machine snapshots are available." as informational
            else
                -- Get snapshot index
                set snapshotIndex to 0
                repeat with i from 1 to count of snapshotList
                    if item i of snapshotList is selectedSnapshot then
                        set snapshotIndex to i
                        exit repeat
                    end if
                end repeat
                
                if snapshotIndex > 0 then
                    try
                        -- Get full snapshot name and details
                        set fullSnapshotName to do shell script "sed -n '" & snapshotIndex & "p' " & quoted form of tempData & " | cut -d'|' -f1"
                        set snapshotDetails to do shell script helperScript & " " & quoted form of fullSnapshotName
                        
                        -- Display detailed information with action buttons
                        set detailChoice to button returned of (display dialog snapshotDetails buttons {"Back", "Toggle TM", "Delete"} default button "Back" with title "Snapshot Management" with icon note)
                        
                        -- Handle actions
                        if detailChoice is "Toggle TM" then
                            if tmStatus is "Enabled" or tmStatus is "Running" then
                                set confirmPrompt to "DISABLE TIME MACHINE" & return & return
                                confirmPrompt = confirmPrompt & "This will disable automatic backups." & return
                                confirmPrompt = confirmPrompt & "Existing snapshots will remain." & return & return
                                confirmPrompt = confirmPrompt & "Continue?"
                                
                                set confirmToggle to button returned of (display dialog confirmPrompt buttons {"Cancel", "Disable"} default button "Cancel" with title "Confirm" with icon caution)
                                
                                if confirmToggle is "Disable" then
                                    try
                                        do shell script "tmutil disable" with administrator privileges
                                        display alert "Success" message "Time Machine has been disabled." as informational
                                        set tmStatus to "Disabled"
                                    on error errMsg
                                        display alert "Error" message "Failed to disable Time Machine:" & return & return & errMsg as critical
                                    end try
                                end if
                            else
                                set confirmPrompt to "ENABLE TIME MACHINE" & return & return
                                confirmPrompt = confirmPrompt & "This will enable automatic backups." & return
                                confirmPrompt = confirmPrompt & "Current destination: " & destInfo & return & return
                                confirmPrompt = confirmPrompt & "Continue?"
                                
                                set confirmToggle to button returned of (display dialog confirmPrompt buttons {"Cancel", "Enable"} default button "Enable" with title "Confirm" with icon note)
                                
                                if confirmToggle is "Enable" then
                                    try
                                        do shell script "tmutil enable" with administrator privileges
                                        display alert "Success" message "Time Machine has been enabled." as informational
                                        set tmStatus to "Enabled"
                                    on error errMsg
                                        display alert "Error" message "Failed to enable Time Machine:" & return & return & errMsg as critical
                                    end try
                                end if
                            end if
                            
                        else if detailChoice is "Delete" then
                            set deletePrompt to "PERMANENT DELETION WARNING" & return & return
                            deletePrompt = deletePrompt & "Deleting:" & return
                            deletePrompt = deletePrompt & selectedSnapshot & return & return
                            deletePrompt = deletePrompt & "THIS CANNOT BE UNDONE!" & return & return
                            deletePrompt = deletePrompt & "Are you sure?"
                            
                            set confirmDelete to button returned of (display dialog deletePrompt buttons {"Cancel", "Delete Forever"} default button "Cancel" with title "Confirm Deletion" with icon stop)
                            
                            if confirmDelete is "Delete Forever" then
                                try
                                    set dateOnly to do shell script "echo " & quoted form of fullSnapshotName & " | sed 's/com.apple.TimeMachine.//'"
                                    do shell script "tmutil deletelocalsnapshots " & quoted form of dateOnly with administrator privileges
                                    
                                    display alert "Deletion Complete" message "The snapshot has been deleted." & return & return & "Refreshing list..." as informational
                                    exit repeat
                                on error errMsg
                                    display alert "Deletion Failed" message "Could not delete snapshot:" & return & return & errMsg as critical
                                end try
                            end if
                        end if
                        
                    on error errMsg
                        display alert "Error" message "Could not retrieve details:" & return & return & errMsg as critical
                    end try
                end if
            end if
        end if
        
    on error errMsg number errNum
        if errNum is not -128 then
            display alert "Error" message "An error occurred:" & return & return & errMsg as critical
            exit repeat
        else
            exit repeat
        end if
    end try
end repeat
EOF
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log "INFO" "GUI closed normally"
    else
        log "WARN" "GUI closed with exit code: $exit_code"
    fi
    
    return $exit_code
}

################################################################################
# Main Execution
################################################################################

main() {
    # Initialize
    init
    
    # Perform checks
    check_os
    check_dependencies
    
    # Launch GUI
    main_gui
    
    log "INFO" "Script completed successfully"
}

# Run main function
main

exit 0
