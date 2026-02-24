#!/usr/bin/env bash
set -euo pipefail

# Kanata setup — run with: sudo ./setup.sh
# Prerequisites: brew install kanata && stow kanata

PLIST_NAME="com.local.kanata"
PLIST_TEMPLATE="$HOME/.config/kanata/kanata.plist"
PLIST_DST="/Library/LaunchDaemons/${PLIST_NAME}.plist"
LOG_DIR="/Library/Logs/Kanata"
USER_HOME="$HOME"

if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run with sudo"
  exit 1
fi

# When run with sudo, $HOME may be /var/root — use SUDO_USER to get the real home
if [[ -n "${SUDO_USER:-}" ]]; then
  USER_HOME=$(eval echo "~$SUDO_USER")
  PLIST_TEMPLATE="$USER_HOME/.config/kanata/kanata.plist"
fi

# Create log directory
mkdir -p "$LOG_DIR"
echo "Created $LOG_DIR"

# Install LaunchDaemon plist, replacing template placeholder with actual home dir
sed "s|__HOME__|$USER_HOME|g" "$PLIST_TEMPLATE" > "$PLIST_DST"
chown root:wheel "$PLIST_DST"
chmod 644 "$PLIST_DST"
echo "Installed $PLIST_DST"

# Unload if already loaded, then load
launchctl bootout system/"$PLIST_NAME" 2>/dev/null || true
launchctl bootstrap system/ "$PLIST_DST"
echo "Loaded $PLIST_NAME"

echo ""
echo "Done! One manual step remaining:"
echo "  System Settings > Privacy & Security > Input Monitoring"
echo "  Add /opt/homebrew/bin/kanata"
