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

# Check if we are in tmux. If not, exit.
if [ -z "$TMUX" ]; then
  echo "Error: Not running inside tmux."
  exit 1
fi

# Generate initial list
window_list=$(print_window_list)

# Feed into fzf inside the popup with custom MacBook/Spotlight styling.
# We bind:
# - ctrl-x: kills the selected session and reloads the list
# - ctrl-d: kills the selected window (tab) and reloads the list
selected=$(echo -e "$window_list" | fzf \
  --ansi \
  --reverse \
  --height=100% \
  --border=none \
  --margin=1,2 \
  --info=hidden \
  --prompt="    " \
  --pointer="➔" \
  --color="bg:-1,bg+:#1e1e2e,fg:#cdd6f4,fg+:#ffffff,hl:#f38ba8,hl+:#f38ba8" \
  --color="pointer:#a6e3a1,prompt:#cba6f7,marker:#f5e0dc,spinner:#f5e0dc" \
  --header="" \
  --preview="$CURRENT_DIR/preview.sh {}" \
  --preview-window="right:50%:border-left" \
  --bind "ctrl-x:execute-silent(tmux kill-session -t \$(echo {} | sed 's/\x1b\[[0-9;]*m//g' | cut -d '[' -f 2 | cut -d ']' -f 1 | cut -d ':' -f 1))+reload($CURRENT_DIR/switcher.sh --list)" \
  --bind "ctrl-d:execute-silent(tmux kill-window -t \$(echo {} | sed 's/\x1b\[[0-9;]*m//g' | cut -d '[' -f 2 | cut -d ']' -f 1))+reload($CURRENT_DIR/switcher.sh --list)"
)

# Extract session name and window index from selection and switch
if [ -n "$selected" ]; then
  # Strip ANSI color codes
  clean_line=$(echo "$selected" | sed 's/\x1b\[[0-9;]*m//g')
  
  # Extract the text inside the square brackets: [session:index]
  content=$(echo "$clean_line" | cut -d "[" -f 2 | cut -d "]" -f 1)
  session_name=$(echo "$content" | cut -d ":" -f 1)
  window_index=$(echo "$content" | cut -d ":" -f 2)
  
  if [ -n "$session_name" ] && [ -n "$window_index" ]; then
    tmux switch-client -t "${session_name}:${window_index}"
  fi
fi
