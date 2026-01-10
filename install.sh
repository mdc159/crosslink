#!/bin/bash
# Crosslink - Install desktop shortcut

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Crosslink desktop shortcut..."

# Create desktop shortcut with correct path
sed "s|INSTALL_PATH|$SCRIPT_DIR|g" "$SCRIPT_DIR/scripts/Crosslink.desktop" > ~/Desktop/Crosslink.desktop

# Make executable
chmod +x ~/Desktop/Crosslink.desktop
chmod +x "$SCRIPT_DIR/launch.sh"

# Trust the desktop file (GNOME)
gio set ~/Desktop/Crosslink.desktop metadata::trusted true 2>/dev/null || true

echo "Done! Crosslink shortcut added to your desktop."
echo ""
echo "If the icon shows 'Untrusted', right-click it and select 'Allow Launching'"
