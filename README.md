# tmux-spotlight

A fast, minimalist [tmux](https://github.com/tmux/tmux) session manager and window switcher, powered by [fzf](https://github.com/junegunn/fzf). Fuzzy-find windows and sessions, launch named project sessions from `zoxide`/`fd`, rename and clean up on the fly — all from one Spotlight-style popup.

I wanted a MacBook-like app switcher for my tmux environment but found existing plugins too cluttered and noisy. So I wrote this. It focuses strictly on window and session management — keeping things minimal, fast, and visually clean without looking like a 90s terminal wizard.

![Demo](assets/demo.gif)

*fuzzy searching windows and killing hoarded sessions.*

## Features

- **Minimal Dependencies:** Just `bash`, `tmux`, and `fzf` (plus `zoxide` and `fd` for folder launching).
- **Named Session Launcher:** Toggle to folder-search mode (`zoxide` + `fd`) and instantly launch or switch to a session auto-named after the project directory. Typing a name with no matches creates a brand-new session under that name.
- **Standalone Launch:** Run it from a plain shell with no tmux running yet — a `tsp` command (auto-installed, no manual setup) opens the same folder-search picker and attaches you straight into the right project session, cold-terminal to tmux in one step.
- **Live Previews:** See active terminal contents or directory file listings on hover. Background colors are stripped to keep code and directories looking clean.
- **Clean Grid Layout:** Information aligns on a neat vertical grid for fast visual parsing, with the session name shown inline for every window — colored green when that session already has a client attached elsewhere, while the window name itself only turns green for the exact window you're currently sitting in.
- **MRU Ordering:** Your most recently used windows float to the top of the list, tracked both from the popup and from native tmux navigation.
- **Inline Renaming:** Rename the highlighted window or its session directly from the popup — no need to drop to a command prompt.
- **Quick Cleanup:** Close individual windows instantly, or kill an entire session with a confirmation prompt first (since it closes every window inside it). Both reload the popup instantly.
- **Cancel-Friendly Prompts:** Rename prompts cancel instantly on Esc (or safely on an empty Enter). The kill-session prompt requires explicitly typing `y`/`Y` to confirm — anything else, including Enter alone, cancels.

## Installation

**Requirement:** Ensure [fzf](https://github.com/junegunn/fzf) is installed. [zoxide](https://github.com/ajeetdsouza/zoxide) and [fd](https://github.com/sharkdp/fd) are recommended for folder-search and named session launching — without either installed, folder mode shows a warning instead of a silent empty list.

Using [TPM](https://github.com/tmux-plugins/tpm), add this to your `~/.tmux.conf`:

```tmux
set -g @plugin 'MeinardEdrei/tmux-spotlight'
```
Then hit `prefix + I` to fetch and install the plugin.

## Keybindings

### Launching

- `prefix + Tab` (Default, inside tmux)
- `Alt + Space` (Triggerless default — use anywhere in tmux)
- **From a plain shell (no tmux running yet):** a `tsp` alias/function is installed automatically the first time the plugin loads (detects bash/zsh/fish via tmux's own `default-shell` setting, and skips if already installed). After starting tmux once, reload your shell and run `tsp` from any terminal — tmux running or not — to open straight into folder-search mode and **attach** to the picked/created session instead of switching, since there's no existing tmux client to switch from.
  - Disable auto-install with `set -g @spotlight-auto-alias 'off'` in your `~/.tmux.conf`.
  - Customize the alias name with `set -g @spotlight-alias-name 'yourname'` (defaults to `tsp`).
  - To install manually instead (or reinstall after changing the name): `~/.tmux/plugins/tmux-spotlight/scripts/install-shell-alias.sh [alias-name]`

### Inside the Popup

- `Enter` : Switch to a window, or launch/switch to a **named session** for the selected folder (auto-named after its directory)
- Typing a name with **no matches** and pressing `Enter` creates a brand-new session under that name
- `Alt + f` : Switch to **project folders** (combines your `zoxide` directory database with `fd`-discovered, unvisited directories)
- `Alt + w` : Switch back to **open windows**
- `Alt + x` : Kill the highlighted **session** (reloads list)
- `Alt + q` : Close the highlighted **window/tab** (reloads list)
- `Alt + r` : Rename the highlighted **window/tab** (prompts for a new name, reloads list)
- `Alt + s` : Rename the **session** the highlighted window belongs to (prompts for a new name, reloads list)

## Configuration

You can override the defaults by adding any of these variables to your `~/.tmux.conf`:

```tmux
# Keybindings
set -g @spotlight-bind 'Tab'
set -g @spotlight-bind-triggerless 'M-Space'

# Dimensions
set -g @spotlight-width '80%'
set -g @spotlight-height '60%'

# Live Preview Settings
set -g @spotlight-preview 'on'
set -g @spotlight-preview-location 'right'
set -g @spotlight-preview-ratio '50%'

# Styling
# custom solid background color (defaults to 'default' for transparent)
# set -g @spotlight-background '#1e1e2e'

# custom selection highlight background (defaults to terminal selection theme)
# options: 'default' | 'none' / 'transparent' | any ANSI color or hex code
# set -g @spotlight-selection 'none'

# customize popup hotkeys (fzf bind syntax)
# set -g @spotlight-bind-folders 'alt-f'
# set -g @spotlight-bind-windows 'alt-w'
# set -g @spotlight-bind-kill-session 'alt-x'
# set -g @spotlight-bind-kill-window 'alt-q'
# set -g @spotlight-bind-rename 'alt-r'
# set -g @spotlight-bind-rename-session 'alt-s'

# search root directory for folder mode (defaults to $HOME)
# set -g @spotlight-folders-dir '$HOME'

# extra comma-separated directory names to exclude from folder search,
# on top of the built-in defaults (.git, node_modules, .cache, .cargo, .npm, .mozilla, .local)
# set -g @spotlight-folders-exclude 'vendor,target,.venv'

# standalone-launch shell alias (see Launching section above)
# set -g @spotlight-auto-alias 'off'
# set -g @spotlight-alias-name 'tsp'
```

MRU (most-recently-used) ordering is tracked in `~/.cache/tmux-spotlight/mru`. Delete this file at any time to reset the ordering back to tmux's default.

## Roadmap

- [x] Zoxide + fd workspace launcher (search & open project folders instantly)
- [x] Live previews (terminal contents / directory listings)
- [x] Quick cleanup (kill sessions/windows from the popup)
- [x] Clean grid layout with dynamic emoji coding
- [x] Session Name Display — show the session a window belongs to directly in the list, not just its window name/path
- [x] Inline Renaming (windows) — rename tmux windows directly from inside the popup
- [x] Inline Renaming (sessions) — rename tmux sessions directly from inside the popup
- [x] Named Session Launching — folders opened via zoxide/fd auto-create a session named after the directory (instead of a numeric default), and typing a brand-new query creates a session under that name
- [x] MRU Ordering — sort the window list by most-recently-used instead of tmux's default creation order, so your last few windows surface first
- [ ] Theme Presets — out-of-the-box support for `catppuccin`, `nord`, `gruvbox`, `tokyonight`
- [x] Standalone Launch — usable from outside tmux (e.g. a fresh shell) to pick a folder/session and attach, instead of requiring an existing tmux client
- [ ] Pane-Level Jumping — search and switch directly to a specific pane, not just the window containing it
- [x] Attached/Detached Session Display — show whether a session already has a client attached elsewhere in the list
- [x] Configurable Folder Excludes — let `@spotlight-folders-exclude` extend the hardcoded fd ignore list (`.git`, `node_modules`, etc.) with project-specific directories
- [ ] Scrollback Search — fuzzy-search a window's terminal history right from the popup and jump straight to that point in copy-mode, live, with no snapshot/save step required
