# tmux-spotlight

A fast, minimalist [tmux](https://github.com/tmux/tmux) session manager and window switcher, powered by [fzf](https://github.com/junegunn/fzf). Fuzzy-find windows, panes, and sessions, launch named project sessions from `zoxide`/`fd` — even from a cold shell before tmux is running — search scrollback live, and rename/clean up on the fly, all from one Spotlight-style popup.

I wanted a MacBook-like app switcher for my tmux environment but found existing plugins too cluttered and noisy. So I wrote this. It focuses strictly on window and session management — keeping things minimal, fast, and visually clean without looking like a 90s terminal wizard.

![Demo](assets/demo.gif)

*fuzzy searching windows, launching named sessions from a folder, and cleaning up hoarded ones.*

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
- **Pane-Level Jumping:** Switch to a specific pane instead of just its window — each row is labeled by what's actually running in it (`nvim`, `npm run dev`, etc.), so you can jump straight to the pane you want in a split window.
- **Scrollback Search:** Fuzzy-search a window's full terminal history across every pane, live — no autosave daemon or snapshot required — and land right on that line in copy-mode. Note: panes running full-screen apps (Neovim, `less`, `htop`, etc.) only ever expose their current screen, not deeper history — those apps use the terminal's alternate-screen mode, which by design isn't recorded in scrollback at all, in tmux or any terminal.

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
- `Alt + e` : Switch to **panes** — jump straight to a specific split (labeled by what's running in it, e.g. `nvim`, `npm`), not just the window containing it
- `Alt + z` : Close the highlighted **pane** (only while in pane mode; reloads list)
- `Alt + /` : **Scrollback search** — fuzzy-search every pane's terminal history in the highlighted window (live, no save/snapshot step) and jump straight to that line in copy-mode
- `Alt + j` / `Alt + n` : Move down · `Alt + k` / `Alt + p` : Move up (wraps around at the top/bottom of the list)
- `Home` / `End` : Jump straight to the first / last item — handy on a long list
- `?` : Show a keybindings cheatsheet, reflecting your actual configured binds (not just the defaults) — press any key to return
- A small "`?` for help" hint is always visible above the list by default, so the help screen isn't something you have to already know about — disable with `set -g @spotlight-show-help-hint 'off'`

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
# set -g @spotlight-bind-panes 'alt-e'
# set -g @spotlight-bind-kill-pane 'alt-z'
# set -g @spotlight-bind-scrollback 'alt-/'
# set -g @spotlight-bind-help '?'
# note: the default '?' bind means typing a literal "?" no longer filters
# the search box — change it if you regularly search for text containing one

# show a small "? for help" hint above the list (defaults to 'on')
# set -g @spotlight-show-help-hint 'off'

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
- [x] Standalone Launch — usable from outside tmux (e.g. a fresh shell) to pick a folder/session and attach, instead of requiring an existing tmux client
- [x] Pane-Level Jumping — search and switch directly to a specific pane, not just the window containing it
- [x] Attached/Detached Session Display — show whether a session already has a client attached elsewhere in the list
- [x] In-Popup Help — a `?` cheatsheet showing all keybinds, reflecting the user's actual configured binds
- [x] Configurable Folder Excludes — let `@spotlight-folders-exclude` extend the hardcoded fd ignore list (`.git`, `node_modules`, etc.) with project-specific directories
- [x] Scrollback Search — fuzzy-search a window's terminal history right from the popup and jump straight to that point in copy-mode, live, with no snapshot/save step required

### v2.1+ (planned)

- [ ] Universal Search — blend windows, panes, folders, and scrollback matches into one ranked list instead of requiring a mode toggle first, so you just type what you're thinking about
- [ ] Tmux Command Palette — fuzzy-run tmux actions themselves (split, sync-panes, toggle status bar, resize, kill-server) without memorizing prefix-key combos
- [ ] Undo-Safety on Kill Actions — a brief grace window to undo a session kill, on top of the existing confirmation prompt
- [ ] First-Run Welcome Tip — a one-time friendly message pointing new users to `?` for help, so discovery doesn't depend on reading the README
- [ ] Accessibility: `NO_COLOR` support and a colorblind-safe palette option
- [ ] Uninstall/Cleanup Helper — a script to cleanly remove the MRU cache and shell alias
- [ ] Theme Presets — out-of-the-box support for `catppuccin`, `nord`, `gruvbox`, `tokyonight`
