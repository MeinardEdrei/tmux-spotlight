# 🔍 tmux-spotlight

spotlight search but for tmux tabs. minimal, fast, and doesn't look like a 90s terminal wizard.

basically, i wanted a MacBook-like app switcher for my tmux windows but found other plugins way too cluttered and noisy. so i wrote this.

<p align="center">
  <kbd>
    <video src="https://github.com/user-attachments/assets/20a4c451-b2fb-4149-a3c8-07f6d982cb87" width="90%" controls autoplay loop muted></video>
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

# preview panel position (right / left / up / down)
set -g @spotlight-preview-location 'right'

# preview panel split size
set -g @spotlight-preview-ratio '50%'
```

## shortcuts in the popup

- `ctrl + x` — kill the highlighted **session** and refresh the list
- `ctrl + d` — close the highlighted **tab/window** and refresh the list
- `enter` — switch to selection
