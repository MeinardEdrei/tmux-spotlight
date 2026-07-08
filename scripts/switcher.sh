#!/usr/bin/env bash

# Resolve the directory of the current script
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Trim leading/trailing whitespace from stdin. Unlike `| xargs` (used
# throughout for the same purpose), this doesn't choke on unmatched quote
# characters — a real occurrence in window/session names, paths, and
# especially free-form scrollback content (contractions, code, etc.).
trim() {
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

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

# Switch to a target if already attached to a tmux client, otherwise attach
# to it fresh — lets this script run standalone from a plain shell too.
# Defined early since several --mode handlers below exit before the main
# fzf invocation section that used to define this.
activate_target() {
  local target="$1"
  if [ -n "$TMUX" ]; then
    tmux switch-client -t "$target"
  else
    tmux attach-session -t "$target"
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

# Remove one exact "session:index" entry (used when a window is killed)
prune_mru_key() {
  local key="$1"
  [ -z "$key" ] && return
  [ -f "$MRU_FILE" ] || return
  grep -vF -x "$key" "$MRU_FILE" > "${MRU_FILE}.tmp" 2>/dev/null
  mv "${MRU_FILE}.tmp" "$MRU_FILE"
}

# Remove every entry belonging to a session (used when a session is killed)
prune_mru_session() {
  local session="$1"
  [ -z "$session" ] && return
  [ -f "$MRU_FILE" ] || return
  grep -v "^${session}:" "$MRU_FILE" > "${MRU_FILE}.tmp" 2>/dev/null
  mv "${MRU_FILE}.tmp" "$MRU_FILE"
}

# If run with --record-mru, log a switch and exit (used by the tmux hook below)
if [ "$1" = "--record-mru" ]; then
  record_mru "$2"
  exit 0
fi

# Helper function to print the formatted window list
print_window_list() {
  # The session driving this very popup is trivially "attached" — exclude it
  # so the marker only flags *other* sessions open elsewhere.
  local current_session=""
  [ -n "$TMUX" ] && current_session=$(tmux display-message -p '#S' 2>/dev/null)

  # Store the window list in a variable to avoid listing twice
  local raw_list
  raw_list=$(tmux list-windows -a -F '#S | #I | #W | #{pane_current_path} | #{session_attached} | #{window_active}' 2>/dev/null)
  
  # First pass: find the maximum length of "$display_name"
  local max_name_len=0
  while read -r line; do
    [ -z "$line" ] && continue
    local name
    name=$(echo "$line" | cut -d '|' -f 3 | trim)
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
    session=$(echo "$line" | cut -d '|' -f 1 | trim)
    index=$(echo "$line" | cut -d '|' -f 2 | trim)
    name=$(echo "$line" | cut -d '|' -f 3 | trim)
    path=$(echo "$line" | cut -d '|' -f 4 | trim)
    attached=$(echo "$line" | cut -d '|' -f 5 | trim)
    active=$(echo "$line" | cut -d '|' -f 6 | trim)

    path_short=$(echo "$path" | sed "s|^$HOME|~|")

    # Ensure window name starts with an emoji for clean visual display
    char_code=$(LC_ALL=C printf '%d' "'$name" 2>/dev/null)
    if [ -n "$char_code" ] && [ "$char_code" -lt 128 ]; then
      display_name="🖥️ $name"
    else
      display_name="$name"
    fi

    # Green is reserved for the window you are actually, currently sitting in
    # right now — not just any window that happens to be "active" within some
    # other attached session (that would make a different terminal's current
    # window look like yours).
    if [ "$session" = "$current_session" ] && [ "$active" = "1" ]; then
      name_color="\e[1;32m"    # Green bold for the window you're in right now
    else
      name_color="\e[1;37m"    # White bold for every other window
    fi

    # Pad manually using bash's character count (${#string}), not printf's
    # %-Ns width — that counts bytes, so multi-byte emoji prefixes throw off
    # the padding math and misalign the whole column.
    pad_len=$((max_name_len - ${#display_name}))
    [ "$pad_len" -lt 0 ] && pad_len=0
    display_name_padded="${display_name}$(printf '%*s' "$pad_len" '')"

    # session_attached is the count of clients attached to this session —
    # color the session name itself (instead of adding another dot glyph next
    # to the existing "session · path" separator) when it's open elsewhere.
    # Safe to reuse green here now that the window-name green above is
    # strictly scoped to your own current session — no more ambiguity.
    if [ "$attached" != "0" ] && [ "$session" != "$current_session" ]; then
      session_colored=$(printf '\e[1;32m%s\e[0m' "$session")
    else
      session_colored=$(printf '\e[38;5;244m%s\e[0m' "$session")
    fi

    # Rank 0 = most recently used; unseen windows sort last (999999), keeping
    # tmux's original order among themselves via a stable sort.
    local rank=999999
    if [ -s "$MRU_FILE" ]; then
      rank=$(awk -v k="${session}:${index}" '$0==k{ln=FNR} END{print (ln ? FNR-ln : 999999)}' "$MRU_FILE")
    fi

    formatted=$(printf "  ${name_color}%s\e[0m  %s\e[38;5;244m · %s\e[0m\t%s:%s" "$display_name_padded" "$session_colored" "$path_short" "$session" "$index")
    output="${output}${rank}${sep}${formatted}"$'\n'
  done <<< "$raw_list"

  echo -n "$output" | sort -t "$sep" -k1,1n -s | cut -d "$sep" -f2-
}

# Helper function to print the formatted pane list — one row per pane instead
# of per window, for jumping straight to a specific split (e.g. the pane
# actually running your dev server) instead of just the containing window.
print_pane_list() {
  local current_session=""
  [ -n "$TMUX" ] && current_session=$(tmux display-message -p '#S' 2>/dev/null)

  local raw_list
  raw_list=$(tmux list-panes -a -F '#{session_name} | #{window_index} | #{pane_index} | #{pane_current_command} | #{pane_current_path} | #{session_attached} | #{window_active} | #{pane_active}' 2>/dev/null)

  # First pass: find the max length of the display label for clean padding
  local max_name_len=0
  while read -r line; do
    [ -z "$line" ] && continue
    local command
    command=$(echo "$line" | cut -d '|' -f 4 | trim)
    local display_name="🖥️ $command"
    local name_len=${#display_name}
    if [ $name_len -gt $max_name_len ]; then
      max_name_len=$name_len
    fi
  done <<< "$raw_list"

  local sep=$'\x01'
  local output=""
  while read -r line; do
    [ -z "$line" ] && continue
    session=$(echo "$line" | cut -d '|' -f 1 | trim)
    window_index=$(echo "$line" | cut -d '|' -f 2 | trim)
    pane_index=$(echo "$line" | cut -d '|' -f 3 | trim)
    command=$(echo "$line" | cut -d '|' -f 4 | trim)
    path=$(echo "$line" | cut -d '|' -f 5 | trim)
    attached=$(echo "$line" | cut -d '|' -f 6 | trim)
    window_active=$(echo "$line" | cut -d '|' -f 7 | trim)
    pane_active=$(echo "$line" | cut -d '|' -f 8 | trim)

    path_short=$(echo "$path" | sed "s|^$HOME|~|")
    display_name="🖥️ $command"

    # Green only for the exact pane you're currently sitting in right now.
    if [ "$session" = "$current_session" ] && [ "$window_active" = "1" ] && [ "$pane_active" = "1" ]; then
      name_color="\e[1;32m"
    else
      name_color="\e[1;37m"
    fi

    # Pad manually using character count (see print_window_list for why).
    pad_len=$((max_name_len - ${#display_name}))
    [ "$pad_len" -lt 0 ] && pad_len=0
    display_name_padded="${display_name}$(printf '%*s' "$pad_len" '')"

    if [ "$attached" != "0" ] && [ "$session" != "$current_session" ]; then
      session_colored=$(printf '\e[1;32m%s\e[0m' "$session")
    else
      session_colored=$(printf '\e[38;5;244m%s\e[0m' "$session")
    fi

    # Reuse the window-level MRU ranking (keyed by session:window, ignoring
    # pane) so pane mode sorts consistently with window mode rather than
    # tracking a whole separate MRU history just for panes.
    local rank=999999
    if [ -s "$MRU_FILE" ]; then
      rank=$(awk -v k="${session}:${window_index}" '$0==k{ln=FNR} END{print (ln ? FNR-ln : 999999)}' "$MRU_FILE")
    fi

    formatted=$(printf "  ${name_color}%s\e[0m  %s\e[38;5;244m · %s\e[0m\t%s:%s.%s" "$display_name_padded" "$session_colored" "$path_short" "$session" "$window_index" "$pane_index")
    output="${output}${rank}${sep}${formatted}"$'\n'
  done <<< "$raw_list"

  echo -n "$output" | sort -t "$sep" -k1,1n -s | cut -d "$sep" -f2-
}

# If run with --list, just print the list and exit
if [ "$1" = "--list" ]; then
  print_window_list
  exit 0
fi

# If run with --panes, print the pane list and exit
if [ "$1" = "--panes" ]; then
  print_pane_list
  exit 0
fi

# Print combined Zoxide frequently-visited and fd unvisited directories
print_folder_list() {
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

    fd_exclude_flags=(--exclude ".git" --exclude "node_modules" --exclude ".cache" --exclude ".cargo" --exclude ".npm" --exclude ".mozilla" --exclude ".local")
    extra_excludes=$(get_tmux_option "@spotlight-folders-exclude" "")
    if [ -n "$extra_excludes" ]; then
      IFS=',' read -ra extra_exclude_list <<< "$extra_excludes"
      for pattern in "${extra_exclude_list[@]}"; do
        pattern=$(echo "$pattern" | trim)
        [ -n "$pattern" ] && fd_exclude_flags+=(--exclude "$pattern")
      done
    fi

    fd_list=$(fd --type d --hidden "${fd_exclude_flags[@]}" --max-depth 4 . "$search_root" 2>/dev/null)
  fi

  if [ "$has_zoxide" -eq 0 ] && [ "$has_fd" -eq 0 ]; then
    echo "⚠️  Install 'zoxide' and/or 'fd' to enable folder launching (see README)."
    return
  fi

  echo -e "$zoxide_list\n$fd_list" | sed 's|/$||' | awk 'NF && !seen[$0]++' | sed "s|^$HOME|~|" | sed 's/^/📂 /'
}

# If run with --zoxide, print the folder list and exit
if [ "$1" = "--zoxide" ]; then
  print_folder_list
  exit 0
fi

# If run with --kill-session, confirm then kill the target session
if [ "$1" = "--kill-session" ]; then
  target=$(echo "$2" | cut -f 2 | cut -d ':' -f 1)
  if [ -n "$target" ]; then
    window_count=$(tmux list-windows -t "$target" 2>/dev/null | wc -l | trim)
    clear
    printf "Kill session \033[1m%s\033[0m and its %s window(s)? (y/N): " "$target" "$window_count"
    read -r confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
      tmux kill-session -t "$target"
      prune_mru_session "$target"
    fi
  fi
  exit 0
fi

# If run with --kill-window, kill the target window
if [ "$1" = "--kill-window" ]; then
  target=$(echo "$2" | cut -f 2)
  if [ -n "$target" ] && echo "$target" | grep -q ":"; then
    tmux kill-window -t "$target"
    prune_mru_key "$target"
  fi
  exit 0
fi

# If run with --kill-pane, kill the target pane
if [ "$1" = "--kill-pane" ]; then
  target=$(echo "$2" | cut -f 2)
  if [ -n "$target" ] && echo "$target" | grep -q "\."; then
    tmux kill-pane -t "$target"
    prune_mru_key "$target"
  fi
  exit 0
fi

# If run with --scrollback, fuzzy-search every pane's terminal history in the
# highlighted window (live, no snapshot/save step) and jump straight to the
# matched line in copy-mode.
if [ "$1" = "--scrollback" ]; then
  target=$(echo "$2" | cut -f 2)
  if [ -n "$target" ] && echo "$target" | grep -q ":"; then
    session_name=$(echo "$target" | cut -d ':' -f 1)
    window_index=$(echo "$target" | cut -d ':' -f 2 | cut -d '.' -f 1)
    window_target="${session_name}:${window_index}"

    clear
    # printf "Searching scrollback...\n"

    sb_lines=""
    while read -r pane_id; do
      [ -z "$pane_id" ] && continue
      # Respect the pane's actual configured history-limit instead of a
      # hardcoded number, otherwise older scrollback silently goes unsearched.
      history_limit=$(tmux display-message -p -t "${window_target}.${pane_id}" '#{history_limit}' 2>/dev/null)
      [ -z "$history_limit" ] && history_limit=2000
      pane_history=$(tmux capture-pane -p -S "-${history_limit}" -t "${window_target}.${pane_id}" 2>/dev/null)
      while IFS= read -r hline; do
        [ -z "$(echo "$hline" | trim)" ] && continue
        sb_lines="${sb_lines}[pane ${pane_id}] ${hline}"$'\n'
      done <<< "$pane_history"
    done < <(tmux list-panes -t "$window_target" -F '#P' 2>/dev/null)

    if [ -z "$sb_lines" ]; then
      clear
      echo "No scrollback content found. Press any key to return..."
      read -rsn1
      exit 0
    fi

    picked=$(echo -n "$sb_lines" | fzf --ansi --reverse --cycle --height=100% --border=none --margin=1,2 --prompt="    " --header="Scrollback search — Esc to cancel" --bind "alt-j:down,alt-n:down,alt-k:up,alt-p:up" --bind "home:first,end:last")

    if [ -n "$picked" ]; then
      pane_id=$(echo "$picked" | sed -n 's/^\[pane \([0-9]*\)\].*/\1/p')
      search_text=$(echo "$picked" | sed 's/^\[pane [0-9]*\] //')
      # Escape basic-regex metacharacters so literal text (paths, brackets,
      # etc.) doesn't get misinterpreted by tmux's copy-mode search.
      search_pattern=$(printf '%s' "$search_text" | sed 's/[.[\*^$\/]/\\&/g')

      if [ -n "$pane_id" ] && [ -n "$search_pattern" ]; then
        activate_target "${window_target}.${pane_id}"
        tmux copy-mode -t "${window_target}.${pane_id}"
        tmux send-keys -t "${window_target}.${pane_id}" -X search-backward "$search_pattern" 2>/dev/null
      fi
    fi
  fi
  exit 0
fi

# Read one keystroke at a time so Esc can cancel immediately, without waiting
# for Enter (plain `read` treats Esc as an ordinary character). Sets
# PROMPT_RESULT and PROMPT_CANCELLED.
prompt_line() {
  PROMPT_RESULT=""
  PROMPT_CANCELLED=0
  local char
  while IFS= read -rsn1 char; do
    if [ "$char" = "$(printf '\033')" ]; then
      PROMPT_CANCELLED=1
      break
    elif [ -z "$char" ]; then
      # Enter was pressed
      break
    elif [ "$char" = $'\x7f' ]; then
      # Backspace
      if [ -n "$PROMPT_RESULT" ]; then
        PROMPT_RESULT="${PROMPT_RESULT%?}"
        printf '\b \b'
      fi
    else
      PROMPT_RESULT="$PROMPT_RESULT$char"
      printf '%s' "$char"
    fi
  done
  echo
}

# Rewrite MRU entries from one session name to another after a rename
rename_mru_session() {
  local old="$1" new="$2"
  [ -f "$MRU_FILE" ] || return
  local tmp="${MRU_FILE}.tmp"
  : > "$tmp"
  while IFS= read -r line; do
    case "$line" in
      "$old":*) echo "${new}:${line#*:}" >> "$tmp" ;;
      *) echo "$line" >> "$tmp" ;;
    esac
  done < "$MRU_FILE"
  mv "$tmp" "$MRU_FILE"
}

# If run with --rename-window, prompt for a new name and rename the target window
if [ "$1" = "--rename-window" ]; then
  target=$(echo "$2" | cut -f 2)
  if [ -n "$target" ] && echo "$target" | grep -q ":"; then
    current_name=$(tmux display-message -p -t "$target" '#W' 2>/dev/null)
    clear
    printf "Rename \033[1m%s\033[0m to (Esc or empty Enter to cancel): " "${current_name:-$target}"
    prompt_line

    if [ "$PROMPT_CANCELLED" -eq 0 ] && [ -n "$PROMPT_RESULT" ]; then
      tmux rename-window -t "$target" "$PROMPT_RESULT"
    fi
  fi
  exit 0
fi

# If run with --rename-session, prompt for a new name and rename the target session
if [ "$1" = "--rename-session" ]; then
  target=$(echo "$2" | cut -f 2 | cut -d ':' -f 1)
  if [ -n "$target" ]; then
    clear
    printf "Rename session \033[1m%s\033[0m to (Esc or empty Enter to cancel): " "$target"
    prompt_line

    if [ "$PROMPT_CANCELLED" -eq 0 ] && [ -n "$PROMPT_RESULT" ]; then
      tmux rename-session -t "$target" "$PROMPT_RESULT"
      rename_mru_session "$target" "$PROMPT_RESULT"
    fi
  fi
  exit 0
fi

# If run with --help, show a keybindings cheatsheet reflecting the user's
# actual configured binds (not just the defaults), then wait for a keypress.
if [ "$1" = "--help" ]; then
  h_folders=$(get_tmux_option "@spotlight-bind-folders" "alt-f")
  h_windows=$(get_tmux_option "@spotlight-bind-windows" "alt-w")
  h_panes=$(get_tmux_option "@spotlight-bind-panes" "alt-e")
  h_kill_session=$(get_tmux_option "@spotlight-bind-kill-session" "alt-x")
  h_kill_window=$(get_tmux_option "@spotlight-bind-kill-window" "alt-q")
  h_kill_pane=$(get_tmux_option "@spotlight-bind-kill-pane" "alt-z")
  h_rename=$(get_tmux_option "@spotlight-bind-rename" "alt-r")
  h_rename_session=$(get_tmux_option "@spotlight-bind-rename-session" "alt-s")
  h_scrollback=$(get_tmux_option "@spotlight-bind-scrollback" "alt-/")
  h_help=$(get_tmux_option "@spotlight-bind-help" "?")

  clear
  printf "\033[1mtmux-spotlight — keybindings\033[0m\n\n"
  printf "  %-14s Switch to the highlighted window, or launch/attach a session for a folder\n" "Enter"
  printf "  %-14s Move down / up (wraps around)\n" "Alt+j Alt+k"
  printf "  %-14s Jump to the first / last item\n" "Home / End"
  printf "  %-14s Switch to project folders (zoxide + fd)\n" "$h_folders"
  printf "  %-14s Switch to open windows\n" "$h_windows"
  printf "  %-14s Switch to panes\n" "$h_panes"
  printf "  %-14s Kill the highlighted session (confirm required)\n" "$h_kill_session"
  printf "  %-14s Close the highlighted window\n" "$h_kill_window"
  printf "  %-14s Close the highlighted pane (pane mode only)\n" "$h_kill_pane"
  printf "  %-14s Rename the highlighted window\n" "$h_rename"
  printf "  %-14s Rename the highlighted session\n" "$h_rename_session"
  printf "  %-14s Search the window's scrollback, live\n" "$h_scrollback"
  printf "  %-14s Show this help\n" "$h_help"
  printf "\n\033[2mHide the \"%s for help\" hint above the list with:\033[0m\n" "$h_help"
  printf "\033[2m  set -g @spotlight-show-help-hint 'off'\033[0m\n"
  printf "\n\033[2mPress any key to return...\033[0m"
  read -rsn1
  exit 0
fi

# Generate initial list. Outside tmux there's nothing to switch to yet, so
# start in folder-search mode instead of an empty window list.
if [ -n "$TMUX" ]; then
  window_list=$(print_window_list)
else
  window_list=$(print_folder_list)
fi

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
bind_rename_session=$(get_tmux_option "@spotlight-bind-rename-session" "alt-s")
bind_panes=$(get_tmux_option "@spotlight-bind-panes" "alt-e")
bind_kill_pane=$(get_tmux_option "@spotlight-bind-kill-pane" "alt-z")
bind_help=$(get_tmux_option "@spotlight-bind-help" "?")
bind_scrollback=$(get_tmux_option "@spotlight-bind-scrollback" "alt-/")

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

# --with-shell forces execute()/reload() actions to run via bash instead of
# the user's $SHELL — needed because fzf's own quoting when substituting {}
# assumes POSIX/bash-style escaping, which breaks under shells with different
# quoting rules (e.g. fish), surfacing as parse errors on scrollback rows
# containing ANSI codes/unicode. Only available on fzf 0.51.0+.
with_shell_flags=()
fzf_version=$(fzf --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ -n "$fzf_version" ] && [ "$(printf '%s\n%s\n' "0.51.0" "$fzf_version" | sort -V | head -1)" = "0.51.0" ]; then
  with_shell_flags=(--with-shell "bash -c")
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

# A small, muted hint so the help screen isn't something you have to already
# know exists. Kept dim/minimal to match the rest of the UI, and toggleable
# for anyone who wants the leanest possible look.
show_help_hint=$(get_tmux_option "@spotlight-show-help-hint" "on")
header_text=""
if [ "$show_help_hint" = "on" ]; then
  header_text=$(printf '\e[38;5;244m%s for help\e[0m' "$bind_help")
fi

# Feed into fzf inside the popup with custom MacBook/Spotlight styling.
selected=$(echo -e "$window_list" | fzf \
  --ansi \
  --reverse \
  --cycle \
  --height=100% \
  --border=none \
  --margin=1,2 \
  --info=hidden \
  --prompt="    " \
  --pointer="" \
  --color="$fzf_colors" \
  --header="$header_text" \
  --delimiter='\t' \
  --with-nth=1 \
  --print-query \
  "${preview_flags[@]}" \
  "${with_shell_flags[@]}" \
  --bind "alt-j:down,alt-n:down,alt-k:up,alt-p:up" \
  --bind "home:first,end:last" \
  --bind "${bind_folders}:change-prompt(    )+reload($CURRENT_DIR/switcher.sh --zoxide)" \
  --bind "${bind_windows}:change-prompt(    )+reload($CURRENT_DIR/switcher.sh --list)" \
  --bind "${bind_panes}:change-prompt(    )+reload($CURRENT_DIR/switcher.sh --panes)" \
  --bind "${bind_kill_session}:execute($CURRENT_DIR/switcher.sh --kill-session {})+reload($CURRENT_DIR/switcher.sh --list)" \
  --bind "${bind_kill_window}:execute-silent($CURRENT_DIR/switcher.sh --kill-window {})+reload($CURRENT_DIR/switcher.sh --list)" \
  --bind "${bind_kill_pane}:execute-silent($CURRENT_DIR/switcher.sh --kill-pane {})+reload($CURRENT_DIR/switcher.sh --panes)" \
  --bind "${bind_rename}:execute($CURRENT_DIR/switcher.sh --rename-window {})+reload($CURRENT_DIR/switcher.sh --list)" \
  --bind "${bind_rename_session}:execute($CURRENT_DIR/switcher.sh --rename-session {})+reload($CURRENT_DIR/switcher.sh --list)" \
  --bind "${bind_help}:execute($CURRENT_DIR/switcher.sh --help)" \
  --bind "${bind_scrollback}:execute($CURRENT_DIR/switcher.sh --scrollback {})"
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
  active_index=$(tmux display-message -p -t "$session_name" '#I' 2>/dev/null)
  record_mru "${session_name}:${active_index}"
  activate_target "$session_name"
}

if [ -n "$match" ]; then
  # Strip target from the hidden field
  target=$(echo "$match" | cut -f 2)

  if echo "$target" | grep -q ":"; then
    # It is a window reference!
    session_name=$(echo "$target" | cut -d ':' -f 1)
    window_index=$(echo "$target" | cut -d ':' -f 2)

    if [ -n "$session_name" ] && [ -n "$window_index" ]; then
      record_mru "${session_name}:${window_index}"
      activate_target "${session_name}:${window_index}"
    fi
  else
    # It is a zoxide directory! Launch (or jump back to) a session named after it.
    target_path=$(echo "$match" | cut -f 1 | trim | sed 's/^📂 //')
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
