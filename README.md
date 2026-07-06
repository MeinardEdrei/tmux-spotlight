# 🔍 tmux-spotlight

spotlight search but for tmux tabs. minimal, fast, and doesn't look like a 90s terminal wizard.

basically, i wanted a MacBook-like app switcher for my tmux windows but found other plugins way too cluttered and noisy. so i wrote this.

<p align="center">
  <kbd>
    <video src="assets/demo.mp4" width="90%" controls autoplay loop muted></video>
  </kbd>
 <br>
 <em>tmux-spotlight in action — fuzzy searching windows and killing hoarded sessions.</em>
</p>

## here's what's different!

- **⚡ zero fluff:** no heavy dependencies. just bash and `fzf`.
- **🖥️ live previews:** see what's actually running in each tab as you hover (and it strips background colors so you don't get ugly jagged blocks).
- **🗃️ clean columns:** everything aligns on a neat vertical grid.
- **❌ tab hoarding cleanup:** press `ctrl+x` to kill an entire session, or `ctrl+d` to close a single tab right inside the picker. it reloads instantly without closing the popup.

## installation

throw this into your `~/.tmux.conf`:

```tmux
set -g @plugin 'MeinardEdrei/tmux-spotlight'
```

hit `prefix + I` to let TPM download and set it up.

## configuration

if you want to override the default keybindings, change the popup size, or tweak the layout, add these to your `~/.tmux.conf`:

```tmux
# defaults to Tab after prefix (so Ctrl+Space then Tab)
set -g @spotlight-bind 'Tab'

# defaults to Alt + Space (triggerless - just hit this anywhere in tmux!)
set -g @spotlight-bind-triggerless 'M-Space'

# customize the spotlight dimensions
set -g @spotlight-width '80%'
set -g @spotlight-height '60%'

# toggle the live preview panel (on / off)
set -g @spotlight-preview 'on'

# preview panel position (right / left / top / bottom)
set -g @spotlight-preview-location 'right'

# preview panel split size
set -g @spotlight-preview-ratio '50%'

# custom solid background color (defaults to 'default' for transparent)
# set -g @spotlight-background '#1e1e2e'

# custom selection highlight background (defaults to terminal selection theme)
# options: 'default' | 'none' / 'transparent' | any ANSI color or hex code
# set -g @spotlight-selection 'none'
```

## shortcuts in the popup

- `ctrl + x` — kill the highlighted **session** and refresh the list
- `ctrl + d` — close the highlighted **tab/window** and refresh the list
- `enter` — switch to selection
