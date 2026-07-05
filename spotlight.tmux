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
popup_width=$(get_tmux_option "@spotlight-width" "80%")
popup_height=$(get_tmux_option "@spotlight-height" "60%")

# Bind the popup commands
tmux bind-key "$key_bind" display-popup -E -w "$popup_width" -h "$popup_height" "$CURRENT_DIR/scripts/switcher.sh"
tmux bind-key -n "$key_bind_triggerless" display-popup -E -w "$popup_width" -h "$popup_height" "$CURRENT_DIR/scripts/switcher.sh"
