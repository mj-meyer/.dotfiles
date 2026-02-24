# Kanata

[Kanata](https://github.com/jtroo/kanata) is a keyboard remapper. This config sets up:

- **Caps Lock** as Escape (tap) / Control (hold)
- **Home row mods** (a=Super, s=Alt, d=Shift, f=Ctrl, j=Ctrl, k=Shift, l=Alt, ;=Super)
- **Fn layer toggle** for F1-F12 keys (top row defaults to media keys)

## Setup

```bash
# Install kanata
brew install kanata

# Stow config files
cd ~/.dotfiles && stow kanata

# Install and start the LaunchDaemon
sudo ~/.config/kanata/setup.sh
```

### Manual step

Kanata needs Input Monitoring permission to grab keyboard input:

**System Settings > Privacy & Security > Input Monitoring** — add `/opt/homebrew/bin/kanata`

Then restart the service:

```bash
sudo launchctl kickstart -k system/com.local.kanata
```

## Karabiner Elements

Kanata uses Karabiner's VirtualHIDDevice driver for keyboard output, so keep it installed. However, Karabiner's grabber conflicts with kanata — disable Karabiner-Elements from launching at login:

**System Settings > General > Login Items** — remove Karabiner-Elements

## Managing the service

```bash
# Restart
sudo launchctl kickstart -k system/com.local.kanata

# Stop
sudo launchctl bootout system/com.local.kanata

# Start (after stop)
sudo launchctl bootstrap system/ /Library/LaunchDaemons/com.local.kanata.plist

# View logs
cat /Library/Logs/Kanata/kanata.out.log
cat /Library/Logs/Kanata/kanata.err.log
```

## Files

- `kanata.kbd` — key remapping config
- `kanata.plist` — LaunchDaemon template (`__HOME__` is replaced by `setup.sh`)
- `setup.sh` — installs the LaunchDaemon and starts kanata
