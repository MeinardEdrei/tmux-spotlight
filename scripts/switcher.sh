#!/usr/bin/env bash

# Resolve the directory of the current script
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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

# Helper function to print the formatted window list
print_window_list() {
  current_session=$(tmux display-message -p '#S')
  # Store the window list in a variable to avoid listing twice
  local raw_list
  raw_list=$(tmux list-windows -a -F '#S | #I | #W | #{pane_current_path} | #{session_attached} | #{window_active}' 2>/dev/null)
  
  # First pass: find the maximum length of "$display_name"
  local max_name_len=0
  while read -r line; do
    [ -z "$line" ] && continue
    local name
    name=$(echo "$line" | cut -d '|' -f 3 | xargs)
    # Ensure window name starts with an emoji for clean visual display
    local char_code
    char_code=$(LC_ALL=C printf '%d' "'$name" 2>/dev/null)
    local display_name
    if [ -n "$char_code" ] && [ "$char_code" -lt 128 ]; then
      display_name="🖥️ $name"
    else
      display_name="$name"
    fi
    local name_len=${#display_name}
    if [ $name_len -gt $max_name_len ]; then
      max_name_len=$name_len
    fi
  done <<< "$raw_list"

  # Second pass: print with dynamic padding
  while read -r line; do
    [ -z "$line" ] && continue
    session=$(echo "$line" | cut -d '|' -f 1 | xargs)
    index=$(echo "$line" | cut -d '|' -f 2 | xargs)
    name=$(echo "$line" | cut -d '|' -f 3 | xargs)
    path=$(echo "$line" | cut -d '|' -f 4 | xargs)
    attached=$(echo "$line" | cut -d '|' -f 5 | xargs)
    active=$(echo "$line" | cut -d '|' -f 6 | xargs)
    
    path_short=$(echo "$path" | sed "s|^$HOME|~|")
    
    # Ensure window name starts with an emoji for clean visual display
    char_code=$(LC_ALL=C printf '%d' "'$name" 2>/dev/null)
    if [ -n "$char_code" ] && [ "$char_code" -lt 128 ]; then
      display_name="🖥️ $name"
    else
      display_name="$name"
    fi
    
    if [ "$attached" = "1" ] && [ "$active" = "1" ]; then
      name_fmt="\e[1;32m%-${max_name_len}.${max_name_len}s\e[0m"    # Green bold for active window name
    else
      name_fmt="\e[1;37m%-${max_name_len}.${max_name_len}s\e[0m"    # White bold for inactive window name
    fi

    printf "  ${name_fmt}  \e[38;5;244m%s · %s\e[0m\t%s:%s\n" "$display_name" "$session" "$path_short" "$session" "$index"
  done <<< "$raw_list"
}

# If run with --list, just print the list and exit
if [ "$1" = "--list" ]; then
  print_window_list
  exit 0
fi

# If run with --zoxide, print combined Zoxide frequently visited and fd unvisited directories
if [ "$1" = "--zoxide" ]; then
  has_zoxide=0
  has_fd=0

  zoxide_list=""
  if command -v zoxide >/dev/null 2>&1; then
    has_zoxide=1
    zoxide_list=$(zoxide query -l 2>/dev/null)
  fi

  fd_list=""
  if command -v fd >/dev/null 2>&1; then
    has_fd=1
    search_root=$(get_tmux_option "@spotlight-folders-dir" "$HOME")
    search_root="${search_root/#\~/$HOME}"
    fd_list=$(fd --type d --hidden --exclude ".git" --exclude "node_modules" --exclude ".cache" --exclude ".cargo" --exclude ".npm" --exclude ".mozilla" --exclude ".local" --max-depth 4 . "$search_root" 2>/dev/null)
  fi

  if [ "$has_zoxide" -eq 0 ] && [ "$has_fd" -eq 0 ]; then
    echo "⚠️  Install 'zoxide' and/or 'fd' to enable folder launching (see README)."
    exit 0
  fi

  echo -e "$zoxide_list\n$fd_list" | sed 's|/$||' | awk 'NF && !seen[$0]++' | sed "s|^$HOME|~|" | sed 's/^/📂 /'
  exit 0
fi

# If run with --kill-session, confirm then kill the target session
if [ "$1" = "--kill-session" ]; then
  target=$(echo "$2" | cut -f 2 | cut -d ':' -f 1)
  if [ -n "$target" ]; then
    window_count=$(tmux list-windows -t "$target" 2>/dev/null | wc -l | xargs)
    clear
    printf "Kill session \033[1m%s\033[0m and its %s window(s)? (y/N): " "$target" "$window_count"
    read -r confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
      tmux kill-session -t "$target"
    fi
  fi
  exit 0
fi

# If run with --kill-window, kill the target window
if [ "$1" = "--kill-window" ]; then
  target=$(echo "$2" | cut -f 2)
  if [ -n "$target" ] && echo "$target" | grep -q ":"; then
    tmux kill-window -t "$target"
  fi
  exit 0
fi

# If run with --rename-window, prompt for a new name and rename the target window
if [ "$1" = "--rename-window" ]; then
  target=$(echo "$2" | cut -f 2)
  if [ -n "$target" ] && echo "$target" | grep -q ":"; then
    current_name=$(tmux display-message -p -t "$target" '#W' 2>/dev/null)
    clear
    printf "Rename \033[1m%s\033[0m to (Esc or Enter to cancel): " "${current_name:-$target}"

    # Read one keystroke at a time so Esc can cancel immediately, without
    # waiting for Enter (plain `read` treats Esc as an ordinary character).
    new_name=""
    cancelled=0
    while IFS= read -rsn1 char; do
      if [ "$char" = "$(printf '\033')" ]; then
        cancelled=1
        break
      elif [ -z "$char" ]; then
        # Enter was pressed
        break
      elif [ "$char" = $'\x7f' ]; then
        # Backspace
        if [ -n "$new_name" ]; then
          new_name="${new_name%?}"
          printf '\b \b'
        fi
      else
        new_name="$new_name$char"
        printf '%s' "$char"
      fi
    done
    echo

    if [ "$cancelled" -eq 0 ] && [ -n "$new_name" ]; then
      tmux rename-window -t "$target" "$new_name"
    fi
  fi
  exit 0
fi

# Check if we are in tmux. If not, exit.
if [ -z "$TMUX" ]; then
  echo "Error: Not running inside tmux."
  exit 1
fi


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
bind_rename=$(get_tmux_option "@spotlight-bind-rename" "alt-r")

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
  --delimiter='\t' \
  --with-nth=1 \
  "${preview_flags[@]}" \
  --bind "alt-j:down,alt-n:down,alt-k:up,alt-p:up" \
  --bind "${bind_folders}:change-prompt(    )+reload($CURRENT_DIR/switcher.sh --zoxide)" \
  --bind "${bind_windows}:change-prompt(    )+reload($CURRENT_DIR/switcher.sh --list)" \
  --bind "${bind_kill_session}:execute($CURRENT_DIR/switcher.sh --kill-session {})+reload($CURRENT_DIR/switcher.sh --list)" \
  --bind "${bind_kill_window}:execute-silent($CURRENT_DIR/switcher.sh --kill-window {})+reload($CURRENT_DIR/switcher.sh --list)" \
  --bind "${bind_rename}:execute($CURRENT_DIR/switcher.sh --rename-window {})+reload($CURRENT_DIR/switcher.sh --list)"
)

# Extract selection and switch
if [ -n "$selected" ]; then
  # Strip target from the hidden field
  target=$(echo "$selected" | cut -f 2)
  
  if echo "$target" | grep -q ":"; then
    # It is a window reference!
    session_name=$(echo "$target" | cut -d ':' -f 1)
    window_index=$(echo "$target" | cut -d ':' -f 2)
    
    if [ -n "$session_name" ] && [ -n "$window_index" ]; then
      tmux switch-client -t "${session_name}:${window_index}"
    fi
  else
    # It is a zoxide directory!
    target_path=$(echo "$selected" | cut -f 1 | xargs | sed 's/^📂 //')
    # Expand ~ to $HOME
    target_path="${target_path/#\~/$HOME}"
    
    if [ -d "$target_path" ]; then
      dir_name=$(basename "$target_path")
      tmux new-window -c "$target_path" -n "$dir_name"
    fi
  fi
fi
