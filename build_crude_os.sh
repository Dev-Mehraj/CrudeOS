#!/usr/bin/env bash
# ============================================================
#                    CrudeOS ISO Builder
# ============================================================
#
# CrudeOS – a polished, modern, macOS‑inspired Linux desktop
# based on Alpine Linux.
#
# Included:
#   - XFCE with a custom two‑panel layout (top bar + bottom dock)
#   - Whisker Menu (styled for a modern OS feel)
#   - Docklike taskbar (modern, centred dock with auto‑hide)
#   - Picom compositor with VSync, 120Hz GLX optimizations, rounded corners
#   - Adw‑gtk3 dark theme + comprehensive GTK CSS polish
#   - Papirus-Dark Icons & Inter Typography
#   - NetworkManager + PipeWire + WirePlumber
#   - CrudeOS Aqua branding & generated scalable SVG wallpaper
#   - Proper user account (crudeos) with auto‑login (LightDM)
#
# Host requirements:
#   - Docker OR Podman
#
# Build:
#   chmod +x build_crude_os.sh
#   ./build_crude_os.sh
#
# ============================================================

set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK="$ROOT/.crudeos-build"
OUT="$ROOT/dist"

ALPINE_VERSION="${ALPINE_VERSION:-3.24.1}"
ALPINE_BRANCH="${ALPINE_BRANCH:-v3.24}"

CRUDEOS_VERSION="${CRUDEOS_VERSION:-1.0.0}"
CRUDEOS_CODENAME="${CRUDEOS_CODENAME:-Aqua}"

ARCH="${ARCH:-x86_64}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-alpine:${ALPINE_VERSION}}"

mkdir -p "$WORK" "$OUT"

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

die() {
    echo >&2
    echo "ERROR: $*" >&2
    exit 1
}

if command -v docker >/dev/null 2>&1; then
    RUNTIME="docker"
elif command -v podman >/dev/null 2>&1; then
    RUNTIME="podman"
else
    die "Docker or Podman is required."
fi

echo
echo "============================================================"
echo "                    CRUDEOS BUILDER"
echo "============================================================"
echo
echo " CrudeOS version : $CRUDEOS_VERSION"
echo " Codename        : $CRUDEOS_CODENAME"
echo " Alpine base     : $ALPINE_VERSION"
echo " Architecture    : $ARCH"
echo " Container       : $CONTAINER_IMAGE"
echo " Runtime         : $RUNTIME"
echo
echo "============================================================"
echo

# ------------------------------------------------------------
# FILE 1: packages.txt (complete list of required packages)
# ------------------------------------------------------------

cat > "$WORK/packages.txt" <<'EOF'
# Core system
alpine-base
linux-lts
linux-firmware

# XFCE desktop environment
xfce4
xfce4-panel
xfce4-session
xfce4-settings
xfwm4
thunar
thunar-volman
tumbler

# XFCE goodies & Plugins
xfce4-docklike-plugin
xfce4-whiskermenu-plugin
xfce4-pulseaudio-plugin
xfce4-power-manager
xfce4-screenshooter
xfce4-taskmanager
xfce4-terminal
xfce4-notifyd
xfce-polkit

# Display Manager
lightdm
lightdm-gtk-greeter

# Theme, Fonts, Icons and Compositor
adw-gtk3
papirus-icon-theme
font-inter
picom
gtk-engines
svg-gtk-engine

# Display / session / hardware
dbus
dbus-x11
elogind
polkit-elogind
libinput
xf86-input-libinput

# Graphics drivers
mesa-dri-gallium
mesa-egl
mesa-gl
xf86-video-amdgpu
xf86-video-intel
xf86-video-nouveau

# Networking
networkmanager
network-manager-applet

# Audio (PipeWire)
pipewire
pipewire-pulse
wireplumber
pavucontrol
alsa-utils

# Basic applications
xarchiver
mousepad
ristretto
htop
git
curl
firefox-esr
EOF

# ------------------------------------------------------------
# FILE 2: mkimage profile (mkimg.crudeos.sh)
# ------------------------------------------------------------

cat > "$WORK/profile_crudeos.sh" <<'EOF'
#!/bin/sh

profile_crudeos()
{
    profile_standard

    title="CrudeOS"
    desc="CrudeOS – modern, lightweight desktop"

    kernel_flavors="lts"

    apks="$apks
        $(grep -v '^#' /work/packages.txt | sed '/^[[:space:]]*$/d')
    "

    apkovl="genapkovl-crudeos.sh"

    kernel_cmdline="$kernel_cmdline quiet loglevel=3 splash"
}
EOF

chmod +x "$WORK/profile_crudeos.sh"

# ------------------------------------------------------------
# FILE 3: APK overlay generator (genapkovl-crudeos.sh)
# ------------------------------------------------------------

cat > "$WORK/genapkovl-crudeos.sh" <<'EOF'
#!/bin/sh

set -eu

tmp="$1"

# Run GUI installation script
/work/install-crudeos-gui.sh "$tmp"

# Mount /proc and /dev for chroot
mount -t proc none "$tmp/proc" || true
mount -t devtmpfs none "$tmp/dev" || true

# Setup crudeos user
chroot "$tmp" /bin/sh -c '
    adduser -D -h /home/crudeos -s /bin/sh -G users crudeos
    for group in audio video input network plugdev wheel; do
        adduser crudeos $group || true
    done
    passwd -d crudeos
    chown -R 1000:1000 /home/crudeos
'

umount "$tmp/proc" || true
umount "$tmp/dev" || true

# Enable services
mkdir -p "$tmp/etc/runlevels/default"
for svc in dbus elogind networkmanager pipewire wireplumber lightdm; do
    ln -sf "/etc/init.d/$svc" "$tmp/etc/runlevels/default/$svc" 2>/dev/null || true
done

# LightDM Autologin Config
mkdir -p "$tmp/etc/lightdm"
cat > "$tmp/etc/lightdm/lightdm.conf" <<'LIGHTDM'
[Seat:*]
autologin-user=crudeos
autologin-session=xfce
greeter-session=lightdm-gtk-greeter
LIGHTDM

# LightDM GTK Greeter Config
cat > "$tmp/etc/lightdm/lightdm-gtk-greeter.conf" <<'GREETER'
[greeter]
theme-name = adw-gtk3-dark
icon-theme-name = Papirus-Dark
font-name = Inter 11
background = /usr/share/backgrounds/crudeos-aqua.svg
default-user-image = #avatar-default
hide-user-image = false
indicators = ~host;~spacer;~clock;~spacer;~session;~power
clock-format = %a, %b %d  %H:%M
GREETER

# Generate the explicit world file
cat > "$tmp/etc/apk/world" <<'WORLD'
alpine-base
linux-lts
linux-firmware
xfce4
xfce4-panel
xfce4-session
xfce4-settings
xfwm4
thunar
thunar-volman
tumbler
xfce4-docklike-plugin
xfce4-whiskermenu-plugin
xfce4-pulseaudio-plugin
xfce4-power-manager
xfce4-screenshooter
xfce4-taskmanager
xfce4-terminal
xfce4-notifyd
xfce-polkit
lightdm
lightdm-gtk-greeter
adw-gtk3
papirus-icon-theme
font-inter
picom
gtk-engines
svg-gtk-engine
dbus
dbus-x11
elogind
polkit-elogind
libinput
xf86-input-libinput
mesa-dri-gallium
mesa-egl
mesa-gl
xf86-video-amdgpu
xf86-video-intel
xf86-video-nouveau
networkmanager
network-manager-applet
pipewire
pipewire-pulse
wireplumber
pavucontrol
alsa-utils
xarchiver
mousepad
ristretto
htop
git
curl
firefox-esr
WORLD

echo "crudeos" > "$tmp/etc/hostname"
echo "[genapkovl] CrudeOS overlay ready."
EOF

chmod +x "$WORK/genapkovl-crudeos.sh"

# ------------------------------------------------------------
# FILE 4: GUI installation script (install-crudeos-gui.sh)
# ------------------------------------------------------------

cat > "$WORK/install-crudeos-gui.sh" <<'EOF'
#!/bin/sh

set -eu

ROOTFS="${1:-/}"
SKEL="$ROOTFS/etc/skel"

# ------------------------------------------------------------
# System Directories
# ------------------------------------------------------------
mkdir -p "$ROOTFS/etc/xdg/picom"
mkdir -p "$ROOTFS/etc/xdg/autostart"
mkdir -p "$ROOTFS/usr/share/backgrounds"
mkdir -p "$ROOTFS/usr/local/bin"

mkdir -p "$SKEL/.config/gtk-3.0"
mkdir -p "$SKEL/.config/gtk-4.0"
mkdir -p "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml"
mkdir -p "$SKEL/.config/xfce4/panel"

# ------------------------------------------------------------
# Generate CrudeOS Aqua Wallpaper
# ------------------------------------------------------------
cat > "$ROOTFS/usr/share/backgrounds/crudeos-aqua.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="3840" height="2160">
  <defs>
    <radialGradient id="grad1" cx="50%" cy="0%" r="100%" fx="50%" fy="0%">
      <stop offset="0%" style="stop-color:#1c2b36;stop-opacity:1" />
      <stop offset="50%" style="stop-color:#12161c;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#0b0d12;stop-opacity:1" />
    </radialGradient>
    <linearGradient id="grad2" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#3a86ff;stop-opacity:0.1" />
      <stop offset="100%" style="stop-color:#ff006e;stop-opacity:0.05" />
    </linearGradient>
  </defs>
  <rect width="100%" height="100%" fill="url(#grad1)" />
  <rect width="100%" height="100%" fill="url(#grad2)" />
  <circle cx="80%" cy="20%" r="800" fill="#2d4254" opacity="0.15" filter="blur(100px)" />
  <circle cx="20%" cy="80%" r="600" fill="#143040" opacity="0.2" filter="blur(150px)" />
</svg>
SVG

# ------------------------------------------------------------
# Custom CSS (Loaded directly into user config for guarantees)
# ------------------------------------------------------------
cat > "$SKEL/.config/gtk-3.0/gtk.css" <<'CSS'
/* ============================================================
   CrudeOS Aqua – GTK3 CSS (Glass UI & Polish)
   ============================================================ */
   
/* Panel Glass Styling */
.xfce4-panel {
    background-color: rgba(18, 22, 28, 0.65);
    font-weight: 500;
}
.xfce4-panel.bottom {
    border-radius: 18px;
    border: 1px solid rgba(255,255,255,0.05);
}

/* Whisker Menu Modernization */
window#whiskermenu-window {
    background-color: rgba(18, 22, 28, 0.95);
    border-radius: 16px;
    border: 1px solid rgba(255,255,255,0.08);
    box-shadow: 0 8px 24px rgba(0,0,0,0.4);
}
#whiskermenu-window button {
    border-radius: 8px;
    padding: 6px;
}

/* Notifications */
#XfceNotifyWindow {
    background-color: rgba(18, 22, 28, 0.95);
    border-radius: 14px;
    border: 1px solid rgba(255,255,255,0.1);
    padding: 10px;
}

/* Tooltips */
tooltip {
    background-color: rgba(11, 13, 18, 0.95);
    border-radius: 8px;
    border: 1px solid rgba(255,255,255,0.05);
}
tooltip label { color: #f0f0f0; }
CSS

cp "$SKEL/.config/gtk-3.0/gtk.css" "$SKEL/.config/gtk-4.0/gtk.css"

# ------------------------------------------------------------
# GTK Settings (Ensure dark mode & font are prioritized)
# ------------------------------------------------------------
cat > "$SKEL/.config/gtk-3.0/settings.ini" <<'GTK3'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Inter 10
gtk-application-prefer-dark-theme=true
gtk-enable-animations=true
gtk-decoration-layout=close,minimize,maximize:
gtk-primary-button-warps-slider=false
GTK3

cp "$SKEL/.config/gtk-3.0/settings.ini" "$SKEL/.config/gtk-4.0/settings.ini"

# ------------------------------------------------------------
# Picom (120Hz Optimized + Rounded Corners)
# ------------------------------------------------------------
cat > "$ROOTFS/etc/xdg/picom/picom.conf" <<'PICOM'
# Backend setup for high refresh / low latency
backend = "glx";
vsync = true;
glx-no-stencil = true;
glx-no-rebind-pixmap = true;
xrender-sync-fence = true;
use-damage = true;

# Hardware Accelerated Rounded Corners
corner-radius = 12;
rounded-corners-exclude = [
  "window_type = 'dock' && class_g != 'xfce4-panel'",
  "window_type = 'tooltip'",
  "class_g = 'xfce4-panel' && window_type = 'dock' && name = 'xfce4-panel-1'",
  "class_g = 'Xfdesktop'"
];

# Smooth Fading
fading = true;
fade-in-step = 0.04;
fade-out-step = 0.04;
fade-delta = 6;
fade-exclude = [];

# Opacity
active-opacity = 1.0;
inactive-opacity = 1.0;
frame-opacity = 1.0;

# Window Types
wintypes:
{
  tooltip = { fade = true; shadow = false; focus = true; };
  dock = { shadow = false; clip-shadow-above = true; };
  dnd = { shadow = false; };
  popup_menu = { opacity = 0.95; fade = true; };
  dropdown_menu = { opacity = 0.95; fade = true; };
};
PICOM

cat > "$ROOTFS/etc/xdg/autostart/crudeos-picom.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Picom
Comment=CrudeOS Compositor
Exec=picom --config /etc/xdg/picom/picom.conf
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESKTOP

# ------------------------------------------------------------
# XFWM4 Configuration (macOS buttons, No compositing)
# ------------------------------------------------------------
cat > "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" <<'XFWM'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
    <property name="vblank_mode" type="string" value="glx"/>
    <property name="button_layout" type="string" value="O|HMC"/>
    <property name="title_alignment" type="string" value="center"/>
    <property name="theme" type="string" value="Default"/>
    <property name="workspace_count" type="int" value="2"/>
    <property name="wrap_workspaces" type="bool" value="false"/>
  </property>
</channel>
XFWM

# ------------------------------------------------------------
# XFCE Panel (Modern Top Bar + Bottom Dock)
# ------------------------------------------------------------
cat > "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" <<'PANEL'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    
    <!-- Top Bar -->
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="length-adjust" type="bool" value="true"/>
      <property name="size" type="uint" value="30"/>
      <property name="background-style" type="uint" value="0"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/> <!-- Whisker -->
        <value type="int" value="2"/> <!-- Spacer/Expand -->
        <value type="int" value="3"/> <!-- Clock -->
        <value type="int" value="4"/> <!-- Spacer/Expand -->
        <value type="int" value="5"/> <!-- Systray -->
        <value type="int" value="6"/> <!-- PulseAudio -->
        <value type="int" value="7"/> <!-- Power -->
      </property>
    </property>

    <!-- Bottom Dock (Docklike) -->
    <value type="int" value="2"/>
    <property name="panel-2" type="empty">
      <property name="position" type="string" value="p=10;x=0;y=0"/>
      <property name="length" type="uint" value="1"/>
      <property name="length-adjust" type="bool" value="true"/>
      <property name="size" type="uint" value="48"/>
      <property name="autohide-behavior" type="uint" value="1"/> <!-- Smart Hide -->
      <property name="plugin-ids" type="array">
        <value type="int" value="8"/> <!-- Docklike -->
      </property>
    </property>
  </property>

  <!-- Plugins config -->
  <property name="plugins" type="empty">
    <!-- 1: Whisker Menu -->
    <property name="plugin-1" type="string" value="whiskermenu"/>
    <!-- 2: Left Spacer -->
    <property name="plugin-2" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <!-- 3: Clock -->
    <property name="plugin-3" type="string" value="clock">
      <property name="mode" type="uint" value="2"/>
    </property>
    <!-- 4: Right Spacer -->
    <property name="plugin-4" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <!-- 5: Systray -->
    <property name="plugin-5" type="string" value="systray">
      <property name="square-icons" type="bool" value="true"/>
    </property>
    <!-- 6: PulseAudio -->
    <property name="plugin-6" type="string" value="pulseaudio">
      <property name="enable-keyboard-shortcuts" type="bool" value="true"/>
    </property>
    <!-- 7: Power Manager -->
    <property name="plugin-7" type="string" value="power-manager-plugin"/>
    <!-- 8: Docklike -->
    <property name="plugin-8" type="string" value="docklike">
      <property name="show-labels" type="bool" value="false"/>
      <property name="indicator-style" type="uint" value="1"/>
      <property name="icon-size" type="uint" value="36"/>
    </property>
  </property>
</channel>
PANEL

# ------------------------------------------------------------
# Session Initialization (Enforce visuals)
# ------------------------------------------------------------
cat > "$ROOTFS/etc/xdg/autostart/crudeos-session.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=CrudeOS Session Setup
Exec=/usr/local/bin/crudeos-session
OnlyShowIn=XFCE;
NoDisplay=true
DESKTOP

cat > "$ROOTFS/usr/local/bin/crudeos-session" <<'INIT'
#!/bin/sh
sleep 1

# Enforce xsettings values dynamically
xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s "adw-gtk3-dark" 2>/dev/null || true
xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s "Papirus-Dark" 2>/dev/null || true
xfconf-query -c xsettings -p /Gtk/FontName -n -t string -s "Inter 10" 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/use_compositing -n -t bool -s false 2>/dev/null || true

# Set Background explicitly to ensure sizing is correct
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -n -t string -s "/usr/share/backgrounds/crudeos-aqua.svg" 2>/dev/null || true
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/image-style -n -t int -s 5 2>/dev/null || true

# Autostart nm-applet if present
if command -v nm-applet >/dev/null 2>&1; then
    nm-applet &
fi

# Pin docklike default apps (Done here to ensure correct path expansion)
xfconf-query -c xfce4-panel -p /plugins/plugin-8/pinned -n -t string -s "firefox-esr.desktop,thunar.desktop,exo-terminal-emulator.desktop,xfce4-settings-manager.desktop" 2>/dev/null || true

exit 0
INIT
chmod +x "$ROOTFS/usr/local/bin/crudeos-session"

# ------------------------------------------------------------
# System Branding
# ------------------------------------------------------------
cat > "$ROOTFS/etc/os-release" <<EOF
NAME="CrudeOS"
ID=crudeos
ID_LIKE=alpine
PRETTY_NAME="CrudeOS ${CRUDEOS_VERSION} (${CRUDEOS_CODENAME})"
VERSION_ID="${CRUDEOS_VERSION}"
VERSION="${CRUDEOS_VERSION} (${CRUDEOS_CODENAME})"
EOF

cat > "$ROOTFS/etc/motd" <<'EOF'
   ____                 _      ____   ____
  / ___|_ __ _   _  __| | ___/ ___| / ___|
 | |   | '__| | | |/ _` |/ _ \___ \| |
 | |___| |  | |_| | (_| |  __/___) | |___
  \____|_|   \__,_|\__,_|\___|____/ \____|

             Welcome to CrudeOS Aqua
           Modern. Glass. Performant.

EOF

echo "[install-gui] CrudeOS Aqua configuration embedded."
EOF

chmod +x "$WORK/install-crudeos-gui.sh"

# ------------------------------------------------------------
# Build Execution (Inside Container)
# ------------------------------------------------------------
echo
echo "[1/5] Pulling Alpine build container..."
echo
"$RUNTIME" pull "$CONTAINER_IMAGE"

echo
echo "[2/5] Preparing Alpine build environment..."
echo
"$RUNTIME" run --rm --privileged \
    -e APORTS_TAG="$ALPINE_BRANCH" \
    -e CRUDEOS_VERSION="$CRUDEOS_VERSION" \
    -e CRUDEOS_CODENAME="$CRUDEOS_CODENAME" \
    -e CRUDEOS_ARCH="$ARCH" \
    -v "$WORK:/work" \
    "$CONTAINER_IMAGE" \
    /bin/sh -c '
set -eu

echo "[container] Installing tools..."
apk add --no-cache alpine-sdk alpine-conf abuild syslinux xorriso squashfs-tools grub mtools git

mkdir -p /work/aports /work/out /work/work /work/root

if [ ! -d /work/aports/.git ]; then
    git clone --depth=1 --branch "$APORTS_TAG" https://gitlab.alpinelinux.org/alpine/aports.git /work/aports
fi

cp /work/profile_crudeos.sh /work/aports/scripts/mkimg.crudeos.sh
cp /work/genapkovl-crudeos.sh /work/aports/scripts/genapkovl-crudeos.sh
cp /work/install-crudeos-gui.sh /work/aports/scripts/install-crudeos-gui.sh
cp /work/packages.txt /work/aports/scripts/packages.txt

chmod +x /work/aports/scripts/*.sh

mkdir -p /root/.abuild
if ! find /etc/apk/keys -maxdepth 1 -type f -name "*.rsa.pub" | grep -q .; then
    abuild-keygen -ain
fi

cd /work/aports
export PROFILENAME="crudeos"
sh ./scripts/mkimage.sh \
    --tag "$APORTS_TAG" \
    --outdir /work/out \
    --workdir /work/work \
    --arch "$CRUDEOS_ARCH" \
    --profile crudeos \
    --repository "https://dl-cdn.alpinelinux.org/alpine/$APORTS_TAG/main" \
    --repository "https://dl-cdn.alpinelinux.org/alpine/$APORTS_TAG/community"
'

# ------------------------------------------------------------
# Extract Output & Cleanup
# ------------------------------------------------------------
echo
echo "[3/5] Locating generated ISO..."
echo
ISO=""
while IFS= read -r candidate; do
    ISO="$candidate"
    break
done < <(find "$WORK/out" -maxdepth 1 -type f -iname "*.iso" | sort)

[ -n "$ISO" ] || die "No ISO was generated."

echo
echo "[4/5] Copying final CrudeOS ISO..."
echo
FINAL="$OUT/crudeos-${CRUDEOS_VERSION}-${ARCH}.iso"
cp -f "$ISO" "$FINAL"

echo
echo "[5/5] Generating checksum..."
echo
sha256sum "$FINAL" | tee "$FINAL.sha256"

echo
echo "============================================================"
echo "                 CRUDEOS BUILD COMPLETE"
echo "============================================================"
echo " ISO:    $FINAL"
echo " SHA256: $(cat "$FINAL.sha256" | awk '{print $1}')"
echo "============================================================"
echo "Test QEMU:"
echo "  qemu-system-x86_64 -enable-kvm -m 4096 -cdrom \"$FINAL\""
echo "============================================================"
