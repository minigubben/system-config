#!/usr/bin/env bash
set -euo pipefail
SRC_DIR="${1:-$HOME/Downloads/TeamSpeak3-Client-linux_amd64}"
INSTALL_DIR="$HOME/.local/opt/TeamSpeak3"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$APP_DIR/teamspeak3.desktop"
if [[ ! -d "$SRC_DIR" ]]; then
  echo "Error: Source directory not found: $SRC_DIR"
  exit 1
fi
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$APP_DIR"
# Copy client files
cp -a "$SRC_DIR"/. "$INSTALL_DIR"/
# Detect launcher script
if [[ -f "$INSTALL_DIR/ts3client_runscript.sh" ]]; then
  LAUNCHER="$INSTALL_DIR/ts3client_runscript.sh"
elif [[ -f "$INSTALL_DIR/ts3client_linux_amd64" ]]; then
  LAUNCHER="$INSTALL_DIR/ts3client_linux_amd64"
else
  echo "Error: Could not find TeamSpeak launcher in $INSTALL_DIR"
  exit 1
fi
chmod +x "$LAUNCHER"
# Best-effort icon detection
ICON="$INSTALL_DIR/styles/default/logo-128x128.png"
if [[ ! -f "$ICON" ]]; then
  ICON="$INSTALL_DIR/styles/default/logo-64x64.png"
fi
if [[ ! -f "$ICON" ]]; then
  ICON="$INSTALL_DIR"
fi
# Convenience command
ln -sf "$LAUNCHER" "$BIN_DIR/teamspeak3"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=TeamSpeak 3 Client
GenericName=Voice Chat
Comment=TeamSpeak 3 VoIP Client
Exec=$LAUNCHER
Icon=$ICON
Terminal=false
Categories=Network;Chat;AudioVideo;
StartupNotify=true
StartupWMClass=TeamSpeak 3
EOF
chmod 644 "$DESKTOP_FILE"
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APP_DIR" || true
fi
echo "Installed TeamSpeak 3 to: $INSTALL_DIR"
echo "Desktop file created: $DESKTOP_FILE"
echo "Run from terminal: $BIN_DIR/teamspeak3"
echo "You may need to log out/in once for some desktop menus to refresh."
