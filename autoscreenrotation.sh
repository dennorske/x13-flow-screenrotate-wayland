#!/usr/bin/env bash
#
# @AUTHOR: Luca Leon Happel
# @DATE  : 2021-11-07 So 19:12 32
# @MODIFIED: Enhanced for systemd service usage
#

# Exit on any error for systemd reliability
set -euo pipefail

# Set up logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${XDG_RUNTIME_DIR:-/tmp}/autoscreenrotation.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Error handling
handle_error() {
    log "ERROR: Auto screen rotation service encountered an error on line $1"
    exit 1
}

trap 'handle_error $LINENO' ERR

log "Starting auto screen rotation service"

# Wait for display server to be ready
wait_for_display() {
    local max_wait=30
    local count=0
    
    # Import display environment from the user session
    if [ -f "/proc/$(pgrep -u "$USER" kwin_wayland | head -1)/environ" ]; then
        export $(grep -z WAYLAND_DISPLAY /proc/$(pgrep -u "$USER" kwin_wayland | head -1)/environ | tr '\0' '\n')
        export $(grep -z XDG_RUNTIME_DIR /proc/$(pgrep -u "$USER" kwin_wayland | head -1)/environ | tr '\0' '\n')
        export $(grep -z XDG_SESSION_TYPE /proc/$(pgrep -u "$USER" kwin_wayland | head -1)/environ | tr '\0' '\n')
    elif [ -f "/proc/$(pgrep -u "$USER" gnome-shell | head -1)/environ" ]; then
        export $(grep -z WAYLAND_DISPLAY /proc/$(pgrep -u "$USER" gnome-shell | head -1)/environ | tr '\0' '\n')
        export $(grep -z XDG_RUNTIME_DIR /proc/$(pgrep -u "$USER" gnome-shell | head -1)/environ | tr '\0' '\n')
        export $(grep -z XDG_SESSION_TYPE /proc/$(pgrep -u "$USER" gnome-shell | head -1)/environ | tr '\0' '\n')
    fi
    
    # Fallback: set default values if not found
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
    export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-wayland}"
    
    while [ $count -lt $max_wait ]; do
        if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
            log "Display server is ready (WAYLAND_DISPLAY=$WAYLAND_DISPLAY, XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR)"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    log "ERROR: Display server not ready after ${max_wait} seconds"
    return 1
}

# Initialize config files with defaults
init_config() {
    mkdir -p ~/.config
    [ ! -f ~/.config/autoscreenrotate ] && echo "true" > ~/.config/autoscreenrotate
    [ ! -f ~/.config/disableinput ] && echo "false" > ~/.config/disableinput
    log "Config files initialized"
}

#######################################
# This function is called each time `motion-sensor` writes to stdout.
# Also, some config files affect this function.
# - if ~/.config/autoscreenrotate is set to true, the screen will be
#   rotated with the device
# - if ~/.config/disableinput is set to true, the keyboard and touchpad
#   will be disabled while the laptop is rotated other than normal
# Arguments:
#   The line that was written to stdout.
#######################################
function processnewcommand {
	# Check if auto rotation is enabled
	if [ ! -f ~/.config/autoscreenrotate ] || [ "$(cat ~/.config/autoscreenrotate)" = "false" ]; then
		log "Auto screen rotation is disabled"
		return
	fi
	
	local disable_input_enabled="false"
	[ -f ~/.config/disableinput ] && disable_input_enabled="$(cat ~/.config/disableinput)"
	
	# Trim whitespace from input
	local trimmed_input
	trimmed_input=$(echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
	
	case "$trimmed_input" in
		"Accelerometer orientation changed: normal")
			log "Screen rotated to normal"
			"$SCRIPT_DIR/screenrotation.sh" "normal" || log "ERROR: Failed to rotate to normal"
			if [ "$disable_input_enabled" = "true" ]; then
				"$SCRIPT_DIR/enableInput.sh" || log "ERROR: Failed to enable input"
			fi
			;;
		"Accelerometer orientation changed: bottom-up")
			log "Screen rotated to inverted"
			"$SCRIPT_DIR/screenrotation.sh" "inverted" || log "ERROR: Failed to rotate to inverted"
			if [ "$disable_input_enabled" = "true" ]; then
				"$SCRIPT_DIR/disableInput.sh" || log "ERROR: Failed to disable input"
			fi
			;;
		"Accelerometer orientation changed: left-up")
			log "Screen rotated to left"
			"$SCRIPT_DIR/screenrotation.sh" "left" || log "ERROR: Failed to rotate to left"
			if [ "$disable_input_enabled" = "true" ]; then
				"$SCRIPT_DIR/disableInput.sh" || log "ERROR: Failed to disable input"
			fi
			;;
		"Accelerometer orientation changed: right-up")
			log "Screen rotated to right"
			"$SCRIPT_DIR/screenrotation.sh" "right" || log "ERROR: Failed to rotate to right"
			if [ "$disable_input_enabled" = "true" ]; then
				"$SCRIPT_DIR/disableInput.sh" || log "ERROR: Failed to disable input"
			fi
			;;
		*)
			log "Unknown sensor event: '$trimmed_input'"
			;;
	esac
}

# Function to check initial orientation and set screen accordingly
check_initial_orientation() {
    log "Checking initial device orientation"
    
    # Get initial sensor reading (timeout after 5 seconds if no reading)
    local initial_orientation
    if initial_orientation=$(timeout 5s monitor-sensor --count=1 2>/dev/null | grep "Accelerometer orientation" | head -1); then
        log "Initial orientation detected: $initial_orientation"
        processnewcommand "$initial_orientation"
    else
        log "Could not detect initial orientation, keeping current screen rotation"
    fi
}

# Cleanup function for graceful shutdown
cleanup() {
    log "Auto screen rotation service stopping"
    kill %1 2>/dev/null || true
    exit 0
}

# Set up signal handlers for graceful shutdown
trap cleanup SIGTERM SIGINT

# Main execution
main() {
    log "Auto screen rotation service starting up"
    
    # Wait for display server
    wait_for_display || exit 1
    
    # Initialize config
    init_config
    
    # Check if monitor-sensor is available
    if ! command -v monitor-sensor >/dev/null 2>&1; then
        log "ERROR: monitor-sensor not found. Please install iio-sensor-proxy"
        exit 1
    fi
    
    # Check initial orientation and set screen accordingly
    check_initial_orientation
    
    # Export function for use in subshell
    export -f processnewcommand
    export SCRIPT_DIR
    export LOG_FILE
    export -f log
    
    log "Starting orientation monitoring loop"
    
    # Start monitoring with better error handling
    monitor-sensor | while IFS= read -r line; do
        if [[ "$line" =~ "Accelerometer orientation changed:" ]]; then
            processnewcommand "$line" || log "ERROR: Failed to process orientation change: $line"
        fi
    done
}

# Run main function
main
