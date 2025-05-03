#!/bin/bash

# Get primary monitor resolution
RES=$(xrandr | grep primary | awk '{print $4}' | sed 's/+.*//')

# Fallback if 'primary' is not marked
if [ -z "$RES" ]; then
  RES=$(xrandr | grep ' connected' | awk '{print $3}' | head -n 1 | sed 's/+.*//')
fi

# Check that the image exists
IMG="$HOME/.config/background_pictures/welcome.jpg"
if [ ! -f "$IMG" ]; then
  echo "Image $IMG not found"
  exit 1
fi

# Create blurred, resized version
TMP="/tmp/welcome.jpg"
magick "$IMG" -resize "$RES" "$TMP"

# Lock screen
i3lock -i "$TMP" --nofork
