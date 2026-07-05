#!/usr/bin/env bash

# The argument $1 is the selected line from fzf:
# "     tmux                 [dotfiles:1]       ~/.config/tmux"
line="$1"

# Clean up ANSI escape sequences
clean_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')

# Extract session name and window index from the square brackets: [session:index]
content=$(echo "$clean_line" | cut -d "[" -f 2 | cut -d "]" -f 1)
session_name=$(echo "$content" | cut -d ":" -f 1)
window_index=$(echo "$content" | cut -d ":" -f 2)

if [ -n "$session_name" ] && [ -n "$window_index" ]; then
  # Capture pane contents with color codes (-e)
  # Then strip background color codes so that text uses the preview pane's full-width background,
  # preventing the "jagged background blocks" look while preserving syntax highlighting colors.
  tmux capture-pane -e -p -t "${session_name}:${window_index}" 2>/dev/null | \
    perl -pe 's/\x1b\[([0-9;]*)(48;2;[0-9]+;[0-9]+;[0-9]+|48;5;[0-9]+|4[0-7]|10[0-7])(;[0-9;]*)?m/\x1b\[\1\3m/g'
fi
