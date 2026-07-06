#!/usr/bin/env bash

# Resolve the directory of the current script
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Helper function to print the formatted window list
print_window_list() {
  current_session=$(tmux display-message -p '#S')
  tmux list-windows -a -F '#S | #I | #W | #{pane_current_path} | #{session_attached} | #{window_active}' | while read -r line; do
    session=$(echo "$line" | cut -d '|' -f 1 | xargs)
    index=$(echo "$line" | cut -d '|' -f 2 | xargs)
    name=$(echo "$line" | cut -d '|' -f 3 | xargs)
    path=$(echo "$line" | cut -d '|' -f 4 | xargs)
    attached=$(echo "$line" | cut -d '|' -f 5 | xargs)
    active=$(echo "$line" | cut -d '|' -f 6 | xargs)
    
    path_short=$(echo "$path" | sed "s|^$HOME|~|")
    
    if [ "$attached" = "1" ] && [ "$active" = "1" ]; then
      name_fmt="\e[1;32m%-15.15s\e[0m"    # Green bold for active window name
      session_fmt="\e[35m%-8s\e[0m"       # Magenta for active session badge
    else
      name_fmt="\e[1;37m%-15.15s\e[0m"    # White bold for inactive window name
      session_fmt="\e[36m%-8s\e[0m"       # Cyan for other session badges
    fi

    badge="[$session:$index]"
    printf "  ${name_fmt}  ${session_fmt}  \e[38;5;244m%s\e[0m\n" "$name" "$badge" "$path_short"
  done
}

# If run with --list, just print the list and exit
if [ "$1" = "--list" ]; then
  print_window_list
  exit 0
fi

# If run with --zoxide, print the frequently visited directories from zoxide and exit
if [ "$1" = "--zoxide" ]; then
  if command -v zoxide >/dev/null 2>&1; then
    zoxide query -l | sed "s|^$HOME|~|"
  else
    echo "  zoxide not installed"
  fi
  exit 0
fi

# If run with --kill-session, kill the target session
if [ "$1" = "--kill-session" ]; then
  target=$(echo "$2" | sed 's/\x1b\[[0-9;]*m//g' | grep -oE '\[[^]]+:[0-9]+\]' | head -n 1 | tr -d '[]' | cut -d ':' -f 1)
  if [ -n "$target" ]; then
    tmux kill-session -t "$target"
  fi
  exit 0
fi

# If run with --kill-window, kill the target window
if [ "$1" = "--kill-window" ]; then
  target=$(echo "$2" | sed 's/\x1b\[[0-9;]*m//g' | grep -oE '\[[^]]+:[0-9]+\]' | head -n 1 | tr -d '[]')
  if [ -n "$target" ]; then
    tmux kill-window -t "$target"
  fi
  exit 0
fi

# Check if we are in tmux. If not, exit.
if [ -z "$TMUX" ]; then
  echo "Error: Not running inside tmux."
  exit 1
fi

# Helper function to get tmux user options
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

# Generate initial list
window_list=$(print_window_list)

# Read preview layout settings
show_preview=$(get_tmux_option "@spotlight-preview" "on")
preview_location=$(get_tmux_option "@spotlight-preview-location" "right")
preview_ratio=$(get_tmux_option "@spotlight-preview-ratio" "50%")
bg_color=$(get_tmux_option "@spotlight-background" "default")
selection_color=$(get_tmux_option "@spotlight-selection" "default")

# Read custom fzf keybindings
bind_folders=$(get_tmux_option "@spotlight-bind-folders" "alt-f")
bind_windows=$(get_tmux_option "@spotlight-bind-windows" "alt-w")
bind_kill_session=$(get_tmux_option "@spotlight-bind-kill-session" "alt-x")
bind_kill_window=$(get_tmux_option "@spotlight-bind-kill-window" "alt-q")

# Translate top/bottom aliases to fzf up/down syntax
if [ "$preview_location" = "top" ]; then
  preview_location="up"
elif [ "$preview_location" = "bottom" ]; then
  preview_location="down"
fi

# Build fzf background options dynamically
fzf_bg="bg:-1"
fzf_preview_bg=""
if [ "$bg_color" != "default" ]; then
  fzf_bg="bg:$bg_color"
  fzf_preview_bg=",preview-bg:$bg_color"
fi

# Build fzf selection options dynamically
fzf_selection=""
if [ "$selection_color" = "none" ] || [ "$selection_color" = "transparent" ]; then
  fzf_selection="bg+:-1"
elif [ "$selection_color" != "default" ]; then
  fzf_selection="bg+:$selection_color"
fi

# Build fzf preview flags dynamically
preview_flags=()
if [ "$show_preview" = "on" ]; then
  # Determine border placement based on location
  border_side="border-left"
  if [ "$preview_location" = "left" ]; then
    border_side="border-right"
  elif [ "$preview_location" = "up" ]; then
    border_side="border-bottom"
  elif [ "$preview_location" = "down" ]; then
    border_side="border-top"
  fi
  
  preview_flags+=(
    --preview "$CURRENT_DIR/preview.sh {}"
    --preview-window "${preview_location}:${preview_ratio}:${border_side}:noinfo"
  )
else
  preview_flags+=(--preview-window "hidden")
fi

# Build fzf color string
fzf_colors="$fzf_bg,fg:#cdd6f4,fg+:#ffffff,hl:#f38ba8,hl+:#f38ba8,prompt:#cba6f7,marker:#f5e0dc,spinner:#f5e0dc$fzf_preview_bg"
if [ -n "$fzf_selection" ]; then
  fzf_colors="$fzf_colors,$fzf_selection"
fi

# Feed into fzf inside the popup with custom MacBook/Spotlight styling.
selected=$(echo -e "$window_list" | fzf \
  --ansi \
  --reverse \
  --height=100% \
  --border=none \
  --margin=1,2 \
  --info=hidden \
  --prompt="    " \
  --pointer="" \
  --color="$fzf_colors" \
  --header="" \
  "${preview_flags[@]}" \
  --bind "alt-j:down,alt-n:down,alt-k:up,alt-p:up" \
  --bind "${bind_folders}:change-prompt(    )+reload($CURRENT_DIR/switcher.sh --zoxide)" \
  --bind "${bind_windows}:change-prompt(    )+reload($CURRENT_DIR/switcher.sh --list)" \
  --bind "${bind_kill_session}:execute-silent($CURRENT_DIR/switcher.sh --kill-session {})+reload($CURRENT_DIR/switcher.sh --list)" \
  --bind "${bind_kill_window}:execute-silent($CURRENT_DIR/switcher.sh --kill-window {})+reload($CURRENT_DIR/switcher.sh --list)"
)

# Extract selection and switch
if [ -n "$selected" ]; then
  # Strip ANSI color codes
  clean_line=$(echo "$selected" | sed 's/\x1b\[[0-9;]*m//g')
  
  # Check if the selection is a directory path (does not contain brackets [session:index])
  if ! echo "$clean_line" | grep -qE '\[[^]]+:[0-9]+\]'; then
    # It is a zoxide directory!
    target_path=$(echo "$clean_line" | xargs)
    # Expand ~ to $HOME
    target_path="${target_path/#\~/$HOME}"
    
    if [ -d "$target_path" ]; then
      dir_name=$(basename "$target_path")
      tmux new-window -c "$target_path" -n "$dir_name"
    fi
  else
    # It is a window reference!
    content=$(echo "$clean_line" | grep -oE "\[[^]]+:[0-9]+\]" | head -n 1)
    content="${content%]}"
    content="${content#[}"
    session_name=$(echo "$content" | cut -d ":" -f 1)
    window_index=$(echo "$content" | cut -d ":" -f 2)
    
    if [ -n "$session_name" ] && [ -n "$window_index" ]; then
      tmux switch-client -t "${session_name}:${window_index}"
    fi
  fi
fi
