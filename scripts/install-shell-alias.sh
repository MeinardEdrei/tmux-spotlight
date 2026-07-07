#!/usr/bin/env bash
# One-time installer: adds a shell alias/function so tmux-spotlight can be
# launched from a plain shell (no tmux running yet) to pick a folder/session
# and attach — not just from inside an existing tmux popup.
#
# Usage: scripts/install-shell-alias.sh [alias-name] [shell-override]
# Defaults to "tsp" to avoid clobbering a "t" alias you may already have.
# shell-override skips auto-detection (used by spotlight.tmux, which can ask
# tmux for its configured default-shell — a more reliable signal than $SHELL).

set -e

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWITCHER_PATH="$PLUGIN_ROOT/scripts/switcher.sh"
ALIAS_NAME="${1:-tsp}"
SHELL_OVERRIDE="$2"
MARKER="# tmux-spotlight standalone launch"

install_for_posix_shell() {
  local rc_file="$1"
  [ -f "$rc_file" ] || touch "$rc_file"

  if grep -qF "$MARKER" "$rc_file" 2>/dev/null; then
    echo "Already installed in $rc_file — skipping."
    return
  fi

  {
    echo ""
    echo "$MARKER"
    echo "alias $ALIAS_NAME='$SWITCHER_PATH'"
  } >> "$rc_file"
  echo "Added 'alias $ALIAS_NAME' to $rc_file. Run: source $rc_file (or open a new terminal)."
}

install_for_fish() {
  local func_dir="$HOME/.config/fish/functions"
  local func_file="$func_dir/${ALIAS_NAME}.fish"

  if [ -f "$func_file" ]; then
    echo "Already installed at $func_file — skipping."
    return
  fi

  mkdir -p "$func_dir"
  {
    echo "$MARKER"
    echo "function $ALIAS_NAME"
    echo "    $SWITCHER_PATH \$argv"
    echo "end"
  } > "$func_file"
  echo "Created $func_file. Fish auto-loads it — just run '$ALIAS_NAME' in a new shell."
}

# $SHELL is the user's *registered login shell*, which often doesn't match
# the shell actually running this script (e.g. fish launched directly by a
# terminal emulator while /etc/passwd still lists bash). Prefer the parent
# process's actual command name, falling back to $SHELL if that fails.
detect_shell() {
  local parent
  parent=$(ps -p "$PPID" -o comm= 2>/dev/null | xargs)
  case "$parent" in
    fish|zsh|bash) echo "$parent"; return ;;
  esac
  basename "${SHELL:-}"
}

shell_name="${SHELL_OVERRIDE:-$(detect_shell)}"

case "$shell_name" in
  fish)
    install_for_fish
    ;;
  zsh)
    install_for_posix_shell "$HOME/.zshrc"
    ;;
  bash)
    install_for_posix_shell "$HOME/.bashrc"
    ;;
  *)
    echo "Unrecognized \$SHELL ('$shell_name'). Add this line to your shell's config manually:"
    echo "  alias $ALIAS_NAME='$SWITCHER_PATH'"
    exit 1
    ;;
esac
