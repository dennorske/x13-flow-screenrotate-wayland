#!/usr/bin/env bash
#
# Toggle Internal Input Devices
# Toggles between enabled and disabled state for internal keyboard and touchpad
#

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
STATE_FILE="$HOME/.config/tablet_mode_state"

# Function to check if devices are currently disabled
devices_disabled() {
    # Check if touchpad is inhibited
    local touchpad_inhibited=false
    for input_dir in /sys/devices/platform/AMDI0010:03/i2c-1/i2c-ELAN1201:00/0018:04F3:3098.0003/input/input*/; do
        if [ -d "$input_dir" ] && [ -f "$input_dir/name" ] && [ -f "$input_dir/inhibited" ]; then
            local device_name=$(cat "$input_dir/name" 2>/dev/null || echo "")
            if [[ "$device_name" =~ ELAN.*Touchpad ]]; then
                local inhibited=$(cat "$input_dir/inhibited" 2>/dev/null || echo "0")
                if [ "$inhibited" = "1" ]; then
                    touchpad_inhibited=true
                    break
                fi
            fi
        fi
    done
    
    # Check if keyboard is inhibited
    local keyboard_inhibited=false
    for event_file in /sys/class/input/event*/device/name; do
        if [ -f "$event_file" ]; then
            local device_name=$(cat "$event_file" 2>/dev/null || echo "")
            local event_path=$(dirname "$event_file")
            local uevent_file="$event_path/uevent"
            
            if [[ "$device_name" == "Asus Keyboard" ]] && [ -f "$uevent_file" ]; then
                local device_path=$(grep "PHYS=" "$uevent_file" 2>/dev/null | cut -d'=' -f2 || echo "")
                if [[ "$device_path" =~ usb-0000:08:00\.3-3/ ]] && [ -f "$event_path/inhibited" ]; then
                    local inhibited=$(cat "$event_path/inhibited" 2>/dev/null || echo "0")
                    if [ "$inhibited" = "1" ]; then
                        keyboard_inhibited=true
                        break
                    fi
                fi
            fi
        fi
    done
    
    # Return true if both are inhibited
    [ "$touchpad_inhibited" = true ] && [ "$keyboard_inhibited" = true ]
}

# Main toggle logic
echo "🔄 Toggling tablet mode..."

if devices_disabled; then
    echo "📱→💻 Switching to laptop mode (enabling internal devices)"
    "$SCRIPT_DIR/enableInput.sh"
    echo "false" > "$STATE_FILE" 2>/dev/null || true
    notify-send "Laptop Mode" "Internal keyboard and touchpad enabled" --icon=input-keyboard || true
else
    echo "💻→📱 Switching to tablet mode (disabling internal devices)" 
    "$SCRIPT_DIR/disableInput.sh"
    echo "true" > "$STATE_FILE" 2>/dev/null || true
    notify-send "Tablet Mode" "Internal keyboard and touchpad disabled" --icon=input-tablet || true
fi

echo "✅ Toggle complete!"