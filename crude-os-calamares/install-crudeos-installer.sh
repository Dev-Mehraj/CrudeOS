#!/bin/sh
# Adds the renamed & reskinned Calamares GUI installer ("Crude OS Setup")
# into the live rootfs. Called from within genapkovl-crudeos.sh.
set -eu
ROOTFS="${1:-/}"

mkdir -p "$ROOTFS/etc/calamares/branding/crudeos" \
         "$ROOTFS/etc/calamares/modules" \
         "$ROOTFS/usr/share/applications" \
         "$ROOTFS/usr/share/icons/crudeos"

cp branding.desc show.qml "$ROOTFS/etc/calamares/branding/crudeos/"
cp settings.yml "$ROOTFS/etc/calamares/"
cp crudeos-welcome.conf "$ROOTFS/etc/calamares/modules/welcome.conf"
cp crudeos-users.conf "$ROOTFS/etc/calamares/modules/users.conf"

# Renamed, reskinned desktop launcher — replaces the generic "Install" icon
cat > "$ROOTFS/usr/share/applications/crudeos-setup.desktop" << 'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=Crude OS Setup
Comment=Install Crude OS to this computer
Exec=sudo calamares -d
Icon=crudeos-installer
Terminal=false
Categories=System;
StartupNotify=true
DESKTOP

cp "$ROOTFS/etc/skel/Desktop/welcome.desktop" \
   "$ROOTFS/etc/skel/Desktop/crudeos-setup.desktop" 2>/dev/null || true
cp "$ROOTFS/usr/share/applications/crudeos-setup.desktop" \
   "$ROOTFS/etc/skel/Desktop/crudeos-setup.desktop"
chmod +x "$ROOTFS/etc/skel/Desktop/crudeos-setup.desktop"

echo "[crudeos] Calamares installer renamed to 'Crude OS Setup' and reskinned (Aqua)."
