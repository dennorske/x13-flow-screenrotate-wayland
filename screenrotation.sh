#!/usr/bin/env bash
#
# @AUTHOR: Luca Leon Happel
# @DATE  : 2021-06-13 So 00:50 57
#
# This is a script that toggles rotation of the screen through xrandr,
# and also toggles rotation of the stylus, eraser and cursor through xsetwacom
# screen = kscreen-doctor -j | jq -r '.outputs[] | select(.name | startswith("eDP")) | .name'

screen="eDP-1"
rotation_num=`kscreen-doctor -j | jq -r '.outputs[] | select(.name | startswith("eDP")) | .rotation'`

# Convert numeric rotation values to text
function get_orientation_text {
	case "$1" in
		"1")
			echo "normal"
			;;
		"2")
			echo "left"
			;;
		"4")
			echo "inverted"
			;;
		"8")
			echo "right"
			;;
		*)
			echo "unknown"
			;;
	esac
}

orientation=`get_orientation_text $rotation_num`

echo $screen
echo $orientation

function wacom_setup {
  # Check if we're running on Wayland
  if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    echo "Note: Wacom rotation on Wayland is handled automatically by the compositor"
    return 0
  fi
  
  # X11 wacom setup (legacy)
  stylus_device=`xsetwacom --list devices | grep "STYLUS" | grep -o -P '(?<=id: ).*(?=type)' 2>/dev/null`
  eraser_device=`xsetwacom --list devices | grep "ERASER" | grep -o -P '(?<=id: ).*(?=type)' 2>/dev/null`
  touch_device=`xsetwacom --list devices | grep "TOUCH" | grep -o -P '(?<=id: ).*(?=type)' 2>/dev/null`
  
  if [ -n "$stylus_device" ]; then
    xsetwacom set $stylus_device Rotate $1 2>/dev/null
  fi
  if [ -n "$eraser_device" ]; then
    xsetwacom set $eraser_device Rotate $1 2>/dev/null
  fi
  if [ -n "$touch_device" ]; then
    xsetwacom set $touch_device Rotate $1 2>/dev/null
  fi
}

function xinput_setup {
  # Check if we're running on Wayland
  if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    echo "Note: Input device mapping on Wayland is handled automatically by the compositor"
    return 0
  fi
  
  # X11 input setup (legacy)
  # For stylus support
  for id in $(xinput --list | sed -n '/.*Stylus/s/.*=\([0-9]\+\).*/\1/p' 2>/dev/null)
  do
    echo "Mapping stylus $id to $screen"
    xinput map-to-output $id $screen 2>/dev/null
  done

  # ASUS ROG Flow X13 - attempt to map touch device
  xinput map-to-output "ELAN9008:00 04F3:2C82" eDP 2>/dev/null || echo "Touch device not found or already mapped"
}

function cycle_left {
	case "$rotation_num" in
		"1")  # normal
			rotate "left"
			;;
		"2")  # left
			rotate "inverted"
			;;
		"4")  # inverted
			rotate "right"
			;;
		"8")  # right
			rotate "normal"
			;;
	esac
}

function cycle_right {
	case "$rotation_num" in
		"1")  # normal
			rotate "right"
			;;
		"8")  # right
			rotate "inverted"
			;;
		"4")  # inverted
			rotate "left"
			;;
		"2")  # left
			rotate "normal"
			;;
	esac
}

function swap {
	case "$rotation_num" in
		"1")  # normal
			rotate "inverted"
			;;
		"4")  # inverted
			rotate "normal"
			;;
		"2")  # left
			rotate "right"
			;;
		"8")  # right
			rotate "left"
			;;
	esac
}

function rotate {
	if [[ -z "$1" ]]; then
		echo "Missing argument!"
		echo "Possible values are: normal, inverted, left, right, cycle_left, cycle_right, swap"
	elif [ "$1" = "normal" ]; then
		kscreen-doctor output.eDP-1.rotation.normal
		wacom_setup none
	elif [ "$1" = "inverted" ]; then
		kscreen-doctor output.eDP-1.rotation.inverted
		wacom_setup half
	elif [ "$1" = "left" ]; then
		kscreen-doctor output.eDP-1.rotation.left
		wacom_setup ccw
	elif [ "$1" = "right" ]; then
		kscreen-doctor output.eDP-1.rotation.right
		wacom_setup cw
	# Cycling
	elif [ "$1" = "cycle_left" ]; then
		cycle_left
	elif [ "$1" = "cycle_right" ]; then
		cycle_right
	# Swapping
	elif [ "$1" = "swap" ]; then
		swap
	fi
  xinput_setup
}

rotate $1
