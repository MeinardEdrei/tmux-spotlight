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

# Track window switches made outside the popup too (e.g. native prefix
# navigation), so MRU ordering reflects real usage, not just popup picks.
tmux set-hook -g after-select-window "run-shell -b '$CURRENT_DIR/scripts/switcher.sh --record-mru \"#{session_name}:#{window_index}\"'"

# Global toggle: jump straight to the previously active window without
# opening the popup at all (like macOS Cmd+Tab). Defaults to a plain Alt+letter
# combo rather than Alt+Tab — Tab specifically is near-universally reserved
# by window managers/compositors at a level below the application (confirmed
# even on tiling WMs like Niri, where it's core engine behavior, not a
# user-configurable bind), unlike plain Alt+<letter> combos which are safe.
key_bind_jump_back=$(get_tmux_option "@spotlight-bind-jump-back" "M-b")
tmux bind-key -n "$key_bind_jump_back" run-shell -b "'$CURRENT_DIR/scripts/switcher.sh' --jump-back"

# Auto-install the standalone-launch shell alias/function on first load, so
# new users don't have to discover and run install-shell-alias.sh manually.
# The script is idempotent (skips if already installed), so this is a no-op
# on every subsequent tmux start. Opt out with @spotlight-auto-alias 'off'.
auto_alias=$(get_tmux_option "@spotlight-auto-alias" "on")
alias_name=$(get_tmux_option "@spotlight-alias-name" "tsp")
if [ "$auto_alias" = "on" ]; then
  # tmux's own default-shell is a more reliable signal than $SHELL, which
  # reflects the registered login shell and can mismatch what's actually
  # running (e.g. fish launched directly by a terminal emulator).
  default_shell_path=$(tmux show-option -gqv default-shell)
  default_shell_name=$(basename "${default_shell_path:-}")
  tmux run-shell -b "'$CURRENT_DIR/scripts/install-shell-alias.sh' '$alias_name' '$default_shell_name' >/dev/null 2>&1"
fi
