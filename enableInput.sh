#!/usr/bin/env bash
#
# Hardware-level internal input device re-enable
# Re-enables internal ASUS keyboard and ELAN touchpad
#

set -euo pipefail

# Function to re-enable internal hardware devices
enable_internal_devices() {
    local enabled_any=false
    
    echo "Re-enabling internal keyboard and touchpad..."
    
    # Method 1: Re-enable ELAN touchpad via input device uninhibit
    echo "Re-enabling ELAN touchpad..."
    local touchpad_enabled=false
    
    # Find ELAN touchpad input device and uninhibit it
    for input_dir in /sys/devices/platform/AMDI0010:03/i2c-1/i2c-ELAN1201:00/0018:04F3:3098.0003/input/input*/; do
        if [ -d "$input_dir" ] && [ -f "$input_dir/name" ]; then
            local device_name=$(cat "$input_dir/name" 2>/dev/null || echo "")
            if [[ "$device_name" =~ ELAN.*Touchpad ]]; then
                local input_num=$(basename "$input_dir")
                echo "Found ELAN touchpad: $input_num"
                
                if [ -f "$input_dir/inhibited" ]; then
                    if sudo bash -c "echo 0 > '$input_dir/inhibited'" 2>/dev/null; then
                        echo "✓ ELAN touchpad uninhibited: $input_num"
                        enabled_any=true
                        touchpad_enabled=true
                    fi
                fi
            fi
        fi
    done
    
    if [ "$touchpad_enabled" = false ]; then
        echo "⚠ Could not uninhibit touchpad via input device, trying driver rebind..."
        if sudo bash -c "echo '0018:04F3:3098.0003' > '/sys/bus/hid/drivers/hid-multitouch/bind'" 2>/dev/null; then
            echo "✓ ELAN touchpad rebound to driver"
            enabled_any=true
        fi
    fi
    
    # Method 2: Re-enable ASUS internal keyboard
    echo "Re-enabling internal ASUS keyboard..."
    local asus_kbd_enabled=false
    
    # Re-enable specific ASUS keyboard devices by their sysfs paths
    for event_file in /sys/class/input/event*/device/name; do
        if [ -f "$event_file" ]; then
            local device_name=$(cat "$event_file" 2>/dev/null || echo "")
            local event_path=$(dirname "$event_file")
            local uevent_file="$event_path/uevent"
            
            # Check if this is an internal ASUS keyboard
            if [[ "$device_name" == "Asus Keyboard" ]] && [ -f "$uevent_file" ]; then
                local device_path=$(grep "PHYS=" "$uevent_file" 2>/dev/null | cut -d'=' -f2 || echo "")
                
                # Only re-enable internal keyboards
                if [[ "$device_path" =~ usb-0000:08:00\.3-3/ ]]; then
                    local event_num=$(basename "$(dirname "$event_file")")
                    echo "Found internal ASUS keyboard: $event_num ($device_path)"
                    
                    # Try to uninhibit the device
                    local input_dir="$event_path"
                    if [ -f "$input_dir/inhibited" ]; then
                        if sudo bash -c "echo 0 > '$input_dir/inhibited'" 2>/dev/null; then
                            echo "✓ ASUS keyboard uninhibited: $event_num"
                            enabled_any=true
                            asus_kbd_enabled=true
                        fi
                    fi
                fi
            fi
        fi
    done
    
    # Method 3: Re-enable xinput devices for Xwayland compatibility
    if command -v xinput >/dev/null 2>&1; then
        echo "Re-enabling Xwayland input devices..."
        
        # Only target ASUS and ELAN devices, not Logitech
        xinput_devices=$(xinput --list 2>/dev/null | grep -i -E '(asus|elan)' | sed -n 's/.*id=\([0-9]\+\).*/\1/p' || true)
        if [ -n "$xinput_devices" ]; then
            for id in $xinput_devices; do
                local device_info=$(xinput --list --name-only "$id" 2>/dev/null || echo "unknown")
                if [[ ! "$device_info" =~ [Ll]ogitech ]]; then
                    if xinput --enable "$id" 2>/dev/null; then
                        echo "✓ Enabled Xwayland device ID: $id ($device_info)"
                        enabled_any=true
                    fi
                fi
            done
        fi
    fi
    
    if [ "$enabled_any" = true ]; then
        echo
        echo "✅ Internal input devices re-enabled successfully."
        echo "⌨️ Laptop mode ready - all devices functional."
    else
        echo
        echo "❌ Warning: No internal input devices were re-enabled."
        echo "Devices may already be enabled or require different approach."
    fi
}

# Main execution
enable_internal_devices