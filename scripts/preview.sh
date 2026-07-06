#!/usr/bin/env bash

# The argument $1 is the selected line from fzf:
# "     tmux                 [dotfiles:1]       ~/.config/tmux"
line="$1"

# Clean up ANSI escape sequences
clean_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')

target=$(echo "$clean_line" | cut -f 2)

# Check if the line is a directory path (does not contain ':')
if ! echo "$target" | grep -q ":"; then
  # Clean path and expand ~ to $HOME
  path=$(echo "$clean_line" | cut -f 1 | xargs | sed 's/^📂 //')
  path="${path/#\~/$HOME}"
  
  if [ -d "$path" ]; then
    echo -e "\e[1;34m📂 Directory: $path\e[0m\n"
    ls -1p --color=always "$path" | head -n 40
  fi
  exit 0
fi

# Extract session name and window index from metadata
session_name=$(echo "$target" | cut -d ':' -f 1)
window_index=$(echo "$target" | cut -d ':' -f 2)

if [ -n "$session_name" ] && [ -n "$window_index" ]; then
  # Capture pane contents with color codes (-e)
  # Then strip background color codes so that text uses the preview pane's full-width background,
  # preventing the "jagged background blocks" look while preserving syntax highlighting colors.
  tmux capture-pane -e -p -t "${session_name}:${window_index}" 2>/dev/null | \
    perl -pe 's/\x1b\[([0-9;]*)(48;2;[0-9]+;[0-9]+;[0-9]+|48;5;[0-9]+|4[0-7]|10[0-7])(;[0-9;]*)?m/\x1b\[\1\3m/g'
fi
