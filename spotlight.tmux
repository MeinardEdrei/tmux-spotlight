#!/usr/bin/env bash

# Resolve the directory where the plugin is cloned
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Helper function to get tmux user options with a fallback default
get_tmux_option() {
  local option="$1"
  local default_value="$2"
  local option_value="$(tmux show-option -gqv "$option")"
  if [ -z "$option_value" ]; then
    echo "$default_value"
  else
    echo "$option_value"
  fi
}

# Read user configurations (or fallback to defaults)
key_bind=$(get_tmux_option "@spotlight-bind" "Tab")
key_bind_triggerless=$(get_tmux_option "@spotlight-bind-triggerless" "M-Space")

# Dynamically default size based on preview options
show_preview=$(get_tmux_option "@spotlight-preview" "on")
preview_location=$(get_tmux_option "@spotlight-preview-location" "right")

default_width="80%"
default_height="60%"

if [ "$show_preview" = "off" ]; then
  default_width="40%"
  default_height="40%"
elif [ "$preview_location" = "top" ] || [ "$preview_location" = "up" ] || [ "$preview_location" = "bottom" ] || [ "$preview_location" = "down" ]; then
  default_height="80%"
fi

popup_width=$(get_tmux_option "@spotlight-width" "$default_width")
popup_height=$(get_tmux_option "@spotlight-height" "$default_height")
bg_color=$(get_tmux_option "@spotlight-background" "default")

style_flag=""
if [ "$bg_color" != "default" ]; then
  style_flag="-s bg=$bg_color"
fi

# Bind the popup commands
if [ -n "$style_flag" ]; then
  tmux bind-key "$key_bind" display-popup $style_flag -E -w "$popup_width" -h "$popup_height" "$CURRENT_DIR/scripts/switcher.sh"
  tmux bind-key -n "$key_bind_triggerless" display-popup $style_flag -E -w "$popup_width" -h "$popup_height" "$CURRENT_DIR/scripts/switcher.sh"
else
  tmux bind-key "$key_bind" display-popup -E -w "$popup_width" -h "$popup_height" "$CURRENT_DIR/scripts/switcher.sh"
  tmux bind-key -n "$key_bind_triggerless" display-popup -E -w "$popup_width" -h "$popup_height" "$CURRENT_DIR/scripts/switcher.sh"
fi
