#!/usr/bin/env bash
#
# Hardware-level internal input device disable for tablet mode
# Disables only internal ASUS keyboard and ELAN touchpad, preserves USB devices
#

set -euo pipefail

# Function to disable internal hardware devices
disable_internal_devices() {
    local disabled_any=false
    
    echo "Disabling internal keyboard and touchpad (hardware level)..."
    
    # Method 1: Disable ELAN touchpad via input device inhibit
    echo "Disabling ELAN touchpad..."
    local touchpad_inhibited=false
    
    # Find ELAN touchpad input device and inhibit it
    for input_dir in /sys/devices/platform/AMDI0010:03/i2c-1/i2c-ELAN1201:00/0018:04F3:3098.0003/input/input*/; do
        if [ -d "$input_dir" ] && [ -f "$input_dir/name" ]; then
            local device_name=$(cat "$input_dir/name" 2>/dev/null || echo "")
            if [[ "$device_name" =~ ELAN.*Touchpad ]]; then
                local input_num=$(basename "$input_dir")
                echo "Found ELAN touchpad: $input_num"
                
                if [ -f "$input_dir/inhibited" ]; then
                    if sudo bash -c "echo 1 > '$input_dir/inhibited'" 2>/dev/null; then
                        echo "✓ ELAN touchpad inhibited: $input_num"
                        disabled_any=true
                        touchpad_inhibited=true
                    fi
                fi
            fi
        fi
    done
    
    if [ "$touchpad_inhibited" = false ]; then
        echo "⚠ Could not inhibit touchpad via input device, trying driver unbind..."
        if sudo bash -c "echo '0018:04F3:3098.0003' > '/sys/bus/hid/drivers/hid-multitouch/unbind'" 2>/dev/null; then
            echo "✓ ELAN touchpad unbound from driver"
            disabled_any=true
        fi
    fi
    
    # Method 2: Disable ASUS internal keyboard via input device paths
    echo "Disabling internal ASUS keyboard..."
    local asus_kbd_disabled=false
    
    # Target specific ASUS keyboard devices by their sysfs paths (internal ones)
    for event_file in /sys/class/input/event*/device/name; do
        if [ -f "$event_file" ]; then
            local device_name=$(cat "$event_file" 2>/dev/null || echo "")
            local event_path=$(dirname "$event_file")
            local uevent_file="$event_path/uevent"
            
            # Check if this is an internal ASUS keyboard by checking the device path
            if [[ "$device_name" == "Asus Keyboard" ]] && [ -f "$uevent_file" ]; then
                local device_path=$(grep "PHYS=" "$uevent_file" 2>/dev/null | cut -d'=' -f2 || echo "")
                
                # Only disable if it's connected to the built-in USB hub (internal)
                if [[ "$device_path" =~ usb-0000:08:00\.3-3/ ]]; then
                    local event_num=$(basename "$(dirname "$event_file")")
                    echo "Found internal ASUS keyboard: $event_num ($device_path)"
                    
                    # Try to unbind the device
                    local input_dir="$event_path"
                    if [ -f "$input_dir/inhibited" ]; then
                        if sudo bash -c "echo 1 > '$input_dir/inhibited'" 2>/dev/null; then
                            echo "✓ ASUS keyboard inhibited: $event_num"
                            disabled_any=true
                            asus_kbd_disabled=true
                        fi
                    fi
                fi
            fi
        fi
    done
    
    # Method 3: Fallback - use xinput for Xwayland compatibility (only for internal devices)
    if command -v xinput >/dev/null 2>&1; then
        echo "Setting up Xwayland input blocking..."
        
        # Only target ASUS and ELAN devices, not Logitech
        xinput_devices=$(xinput --list 2>/dev/null | grep -i -E '(asus|elan)' | sed -n 's/.*id=\([0-9]\+\).*/\1/p' || true)
        if [ -n "$xinput_devices" ]; then
            for id in $xinput_devices; do
                local device_info=$(xinput --list --name-only "$id" 2>/dev/null || echo "unknown")
                if [[ ! "$device_info" =~ [Ll]ogitech ]]; then
                    if xinput --disable "$id" 2>/dev/null; then
                        echo "✓ Disabled Xwayland device ID: $id ($device_info)"
                        disabled_any=true
                    fi
                fi
            done
        fi
    fi
    
    if [ "$disabled_any" = true ]; then
        echo
        echo "✅ Internal input devices disabled successfully."
        echo "📱 Tablet mode ready - external USB devices remain functional."
    else
        echo
        echo "❌ Warning: No internal input devices were disabled."
        echo "This may require different permissions or kernel modules."
    fi
    
    echo
    echo "🔄 Use ./enableInput.sh to re-enable internal devices."
}

# Main execution
disable_internal_devices
