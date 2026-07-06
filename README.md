# tmux-spotlight

A fast, minimalist fuzzy finder for tmux windows and sessions, powered by `fzf`.

I wanted a MacBook-like app switcher for my tmux environment but found existing plugins too cluttered and noisy. So I wrote this. It currently focuses strictly on window and session management—keeping things minimal, fast, and visually clean without looking like a 90s terminal wizard.

<p align="center">
  <img src="assets/demo.gif" width="90%" alt="tmux-spotlight demo">
  <br>
  <em>fuzzy searching windows and killing hoarded sessions.</em>
</p>

## Features

- **Minimal Dependencies:** Just `bash`, `tmux`, and `fzf`.
- **Live Previews:** See tab contents on hover. Background colors are automatically stripped to prevent jagged block rendering.
- **Clean Grid Layout:** Information aligns on a neat vertical grid for fast visual parsing.
- **Quick Cleanup:** Kill entire sessions or close individual windows directly inside the picker. The popup reloads instantly.

## Installation

**Requirement:** Ensure [fzf](https://github.com/junegunn/fzf) is installed.

Using [TPM](https://github.com/tmux-plugins/tpm), add this to your `~/.tmux.conf`:

```tmux
set -g @plugin 'MeinardEdrei/tmux-spotlight'
```
Then hit `prefix + I` to fetch and install the plugin.

## Keybindings

### Launching

- `prefix + Tab` (Default)
- `Alt + Space` (Triggerless default — use anywhere in tmux)

### Inside the Popup

- `Enter` : Switch to the highlighted window/session
- `Ctrl + x` : Kill the highlighted **session** (reloads list)
- `Ctrl + d` : Close the highlighted **window/tab** (reloads list)

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
```

## Roadmap

Right now, `tmux-spotlight` is an efficient session manager, but I'm planning to expand it into a broader workspace navigation tool. Coming soon:

- **Directory Jumper:** Search frequently visited folders and open them instantly in a new tmux window.
- **Theme Presets:** Out-of-the-box support for popular themes (e.g., `catppuccin`, `nord`, `gruvbox`, `tokyonight`).
- **Inline Renaming:** Rename tmux windows and sessions directly from inside the popup.
- **Smart Filtering:** Minor QoL toggles, like hiding the current active window from the search list.
