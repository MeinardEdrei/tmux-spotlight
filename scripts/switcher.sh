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

# Most-recently-used tracking: a flat file where each line is a
# "session:window_index" key, appended in order of use (most recent = last).
MRU_FILE="$HOME/.cache/tmux-spotlight/mru"

record_mru() {
  local key="$1"
  [ -z "$key" ] && return
  mkdir -p "$(dirname "$MRU_FILE")"
  touch "$MRU_FILE"
  grep -vF -x "$key" "$MRU_FILE" > "${MRU_FILE}.tmp" 2>/dev/null
  mv "${MRU_FILE}.tmp" "$MRU_FILE"
  echo "$key" >> "$MRU_FILE"
  # Cap growth: keep only the most recent 200 entries
  tail -n 200 "$MRU_FILE" > "${MRU_FILE}.tmp" && mv "${MRU_FILE}.tmp" "$MRU_FILE"
}

# If run with --record-mru, log a switch and exit (used by the tmux hook below)
if [ "$1" = "--record-mru" ]; then
  record_mru "$2"
  exit 0
fi

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

  # Second pass: format each row, prefixed with its MRU rank for sorting below
  local sep=$'\x01'
  local output=""
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

    # Rank 0 = most recently used; unseen windows sort last (999999), keeping
    # tmux's original order among themselves via a stable sort.
    local rank=999999
    if [ -s "$MRU_FILE" ]; then
      rank=$(awk -v k="${session}:${index}" '$0==k{ln=FNR} END{print (ln ? FNR-ln : 999999)}' "$MRU_FILE")
    fi

    formatted=$(printf "  ${name_fmt}  \e[38;5;244m%s · %s\e[0m\t%s:%s" "$display_name" "$session" "$path_short" "$session" "$index")
    output="${output}${rank}${sep}${formatted}"$'\n'
  done <<< "$raw_list"

  echo -n "$output" | sort -t "$sep" -k1,1n -s | cut -d "$sep" -f2-
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
  --print-query \
  "${preview_flags[@]}" \
  --bind "alt-j:down,alt-n:down,alt-k:up,alt-p:up" \
  --bind "${bind_folders}:change-prompt(    )+reload($CURRENT_DIR/switcher.sh --zoxide)" \
  --bind "${bind_windows}:change-prompt(    )+reload($CURRENT_DIR/switcher.sh --list)" \
  --bind "${bind_kill_session}:execute($CURRENT_DIR/switcher.sh --kill-session {})+reload($CURRENT_DIR/switcher.sh --list)" \
  --bind "${bind_kill_window}:execute-silent($CURRENT_DIR/switcher.sh --kill-window {})+reload($CURRENT_DIR/switcher.sh --list)" \
  --bind "${bind_rename}:execute($CURRENT_DIR/switcher.sh --rename-window {})+reload($CURRENT_DIR/switcher.sh --list)"
)

# With --print-query, fzf prints the typed query as the first line, followed
# by the matched line (if any). Split them apart.
query=$(echo "$selected" | sed -n '1p')
match=$(echo "$selected" | sed -n '2p')

# Sanitize a string into a valid tmux session name (no periods/colons).
sanitize_session_name() {
  echo "$1" | tr '.:' '__'
}

# Create (if needed) and switch to a named session rooted at a directory.
launch_named_session() {
  local session_name
  session_name=$(sanitize_session_name "$1")
  local start_dir="$2"

  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    tmux new-session -d -s "$session_name" -c "$start_dir"
  fi
  tmux switch-client -t "$session_name"
  active_index=$(tmux display-message -p -t "$session_name" '#I' 2>/dev/null)
  record_mru "${session_name}:${active_index}"
}

if [ -n "$match" ]; then
  # Strip target from the hidden field
  target=$(echo "$match" | cut -f 2)

  if echo "$target" | grep -q ":"; then
    # It is a window reference!
    session_name=$(echo "$target" | cut -d ':' -f 1)
    window_index=$(echo "$target" | cut -d ':' -f 2)

    if [ -n "$session_name" ] && [ -n "$window_index" ]; then
      tmux switch-client -t "${session_name}:${window_index}"
      record_mru "${session_name}:${window_index}"
    fi
  else
    # It is a zoxide directory! Launch (or jump back to) a session named after it.
    target_path=$(echo "$match" | cut -f 1 | xargs | sed 's/^📂 //')
    # Expand ~ to $HOME
    target_path="${target_path/#\~/$HOME}"

    if [ -d "$target_path" ]; then
      dir_name=$(basename "$target_path")
      launch_named_session "$dir_name" "$target_path"
    fi
  fi
elif [ -n "$query" ]; then
  # No match for the typed query — create a brand-new session under that name.
  launch_named_session "$query" "$HOME"
fi
