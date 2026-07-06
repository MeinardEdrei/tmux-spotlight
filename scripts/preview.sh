#!/usr/bin/env bash

# The argument $1 is the selected line from fzf:
# "     tmux                 [dotfiles:1]       ~/.config/tmux"
line="$1"

# Clean up ANSI escape sequences
clean_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')

# Check if the line is a directory path (does not contain brackets [session:index])
if ! echo "$clean_line" | grep -qE '\[[^]]+:[0-9]+\]'; then
  # Clean path and expand ~ to $HOME
  path=$(echo "$clean_line" | xargs)
  path="${path/#\~/$HOME}"
  
  if [ -d "$path" ]; then
    echo -e "\e[1;34m📂 Directory: $clean_line\e[0m\n"
    ls -1p --color=always "$path" | head -n 40
  fi
  exit 0
fi

# Extract session name and window index from the square brackets: [session:index]
content=$(echo "$clean_line" | grep -oE "\[[^]]+:[0-9]+\]" | head -n 1)
content="${content%]}"
content="${content#[}"
session_name=$(echo "$content" | cut -d ":" -f 1)
window_index=$(echo "$content" | cut -d ":" -f 2)

if [ -n "$session_name" ] && [ -n "$window_index" ]; then
  # Capture pane contents with color codes (-e)
  # Then strip background color codes so that text uses the preview pane's full-width background,
  # preventing the "jagged background blocks" look while preserving syntax highlighting colors.
  tmux capture-pane -e -p -t "${session_name}:${window_index}" 2>/dev/null | \
    perl -pe 's/\x1b\[([0-9;]*)(48;2;[0-9]+;[0-9]+;[0-9]+|48;5;[0-9]+|4[0-7]|10[0-7])(;[0-9;]*)?m/\x1b\[\1\3m/g'
fi
