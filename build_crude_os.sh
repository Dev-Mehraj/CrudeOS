#!/usr/bin/env bash
# ==============================================================================
# CrudeOS ISO Builder — Enhanced Edition (CrudeOS Aqua)
# ==============================================================================
# Base: Alpine Linux (v3.24) with customized XFCE desktop
# Style: CrudeOS Aqua — macOS-inspired dark glass, floating dock, 120Hz VSync
# ==============================================================================

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

die() {
    echo >&2 "[CrudeOS ERROR] $*"
    exit 1
}

if command -v docker >/dev/null 2>&1; then
    RUNTIME="docker"
elif command -v podman >/dev/null 2>&1; then
    RUNTIME="podman"
else
    die "Docker or Podman is required on host system."
fi

echo "============================================================"
echo " CrudeOS Aqua Desktop ISO Builder"
echo " Version     : $CRUDEOS_VERSION ($CRUDEOS_CODENAME)"
echo " Base        : Alpine $ALPINE_VERSION ($ALPINE_BRANCH)"
echo " Arch        : $ARCH"
echo " Container   : $RUNTIME ($CONTAINER_IMAGE)"
echo "============================================================"

# ------------------------------------------------------------------------------
# 1. Package Manifest (Verified Alpine 3.24 main & community repositories)
# ------------------------------------------------------------------------------
cat > "$WORK/packages.txt" <<'EOF'
# Core System & Kernel
alpine-base
linux-lts
linux-firmware
sudo
curl
wget
ca-certificates
tzdata

# X11 & Input / Video Stack
xorg-server
xf86-input-libinput
libinput
mesa-dri-gallium
mesa-egl
mesa-gl
xf86-video-amdgpu
xf86-video-intel
xf86-video-nouveau
xf86-video-vesa

# Session & Display Management
dbus
dbus-x11
elogind
polkit-elogind
lightdm
lightdm-gtk-greeter

# XFCE Desktop Environment
xfce4-session
xfce4-panel
xfce4-settings
xfwm4
thunar
thunar-volman
thunar-archive-plugin
tumbler
xfce4-terminal
mousepad
xfce4-taskmanager
xfce4-screenshooter
xfce-polkit

# Dock, Launcher & Goodies
xfce4-docklike-plugin
xfce4-whiskermenu-plugin
xfce4-pulseaudio-plugin
xfce4-statusnotifier-plugin
xfce4-power-manager
xfce4-notifyd
rofi

# Visual Identity, Fonts & Compositor
picom
adw-gtk3
papirus-icon-theme
font-inter
font-noto
font-noto-emoji
feh

# Audio (PipeWire)
pipewire
pipewire-pulse
wireplumber
pavucontrol
alsa-utils

# Networking
networkmanager
network-manager-applet

# Default Web Browser & Utilities
firefox-esr
xarchiver

# Crude OS Setup (Calamares GUI installer, rebranded)
calamares
calamares-extensions
polkit
parted
EOF

# ------------------------------------------------------------------------------
# 2. mkimage Profile
# ------------------------------------------------------------------------------
cat > "$WORK/profile_crudeos.sh" <<'EOF'
#!/bin/sh

profile_crudeos()
{
    profile_standard
    title="CrudeOS"
    desc="CrudeOS Aqua Desktop (Alpine Linux)"
    kernel_flavors="lts"
    apks="$apks $(grep -v '^#' /work/packages.txt | sed '/^[[:space:]]*$/d')"
    apkovl="genapkovl-crudeos.sh"
    kernel_cmdline="$kernel_cmdline quiet loglevel=3 splash"
}
EOF
chmod +x "$WORK/profile_crudeos.sh"

# ------------------------------------------------------------------------------
# 3. APK Overlay Generator (Alpine Live ISO contract compliant)
# ------------------------------------------------------------------------------
cat > "$WORK/genapkovl-crudeos.sh" <<'EOF'
#!/bin/sh
set -eu

TARBALL="$1"
tmp="$(mktemp -d)"

cleanup() {
    rm -rf "$tmp"
}
trap cleanup EXIT

# Invoke configuration generator inside staging root
/work/install-crudeos-gui.sh "$tmp"

# Install & rebrand the Calamares GUI installer as "Crude OS Setup"
/work/install-crudeos-installer.sh "$tmp"

# Generate APK world file
grep -v '^#' /work/packages.txt | sed '/^[[:space:]]*$/d' > "$tmp/etc/apk/world"

# Hostname
echo "crudeos" > "$tmp/etc/hostname"

# Network hosts
cat > "$tmp/etc/hosts" <<'HOSTS'
127.0.0.1   localhost crudeos
::1         localhost crudeos ip6-localhost ip6-loopback
HOSTS

# Enable OpenRC runlevels
mkdir -p "$tmp/etc/runlevels/boot" "$tmp/etc/runlevels/default"
for svc in bootmisc hostname modules sysctl; do
    ln -sf "/etc/init.d/$svc" "$tmp/etc/runlevels/boot/$svc" 2>/dev/null || true
done

for svc in dbus elogind networkmanager lightdm local; do
    ln -sf "/etc/init.d/$svc" "$tmp/etc/runlevels/default/$svc" 2>/dev/null || true
done

# LightDM Autologin Configuration
mkdir -p "$tmp/etc/lightdm"
cat > "$tmp/etc/lightdm/lightdm.conf" <<'LIGHTDM'
[Seat:*]
autologin-user=crudeos
autologin-session=xfce
greeter-session=lightdm-gtk-greeter
user-session=xfce
LIGHTDM

cat > "$tmp/etc/lightdm/lightdm-gtk-greeter.conf" <<'GREETER'
[greeter]
theme-name = adw-gtk3-dark
icon-theme-name = Papirus-Dark
font-name = Inter 10
background = /usr/share/backgrounds/crudeos/crudeos-aqua.svg
default-user-image = #avatar-default
indicators = ~spacer;~clock;~power
clock-format = %a, %b %d  %l:%M %p
position = 50%,center 50%,center
screensaver-timeout = 60
GREETER

# Package the apkovl tarball
tar -c -C "$tmp" -z -f "$TARBALL" .
echo "[genapkovl] Successfully built CrudeOS overlay tarball: $TARBALL"
EOF
chmod +x "$WORK/genapkovl-crudeos.sh"

# ------------------------------------------------------------------------------
# 4. GUI & Desktop Environment Asset Generator
# ------------------------------------------------------------------------------
cat > "$WORK/install-crudeos-gui.sh" <<'EOF'
#!/bin/sh
set -eu

ROOTFS="${1:-/}"
SKEL="$ROOTFS/etc/skel"

mkdir -p "$SKEL/.config/gtk-3.0" \
         "$SKEL/.config/gtk-4.0" \
         "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml" \
         "$SKEL/.config/xfce4/panel" \
         "$SKEL/.config/rofi" \
         "$SKEL/.config/autostart" \
         "$ROOTFS/etc/xdg/gtk-3.0" \
         "$ROOTFS/etc/xdg/gtk-4.0" \
         "$ROOTFS/etc/xdg/picom" \
         "$ROOTFS/etc/xdg/autostart" \
         "$ROOTFS/etc/local.d" \
         "$ROOTFS/etc/sudoers.d" \
         "$ROOTFS/usr/share/themes/CrudeOS-Aqua/xfwm4" \
         "$ROOTFS/usr/share/backgrounds/crudeos" \
         "$ROOTFS/usr/local/bin"

# ------------------------------------------------------------------------------
# User & Live ISO Initialization Service (OpenRC local.d)
# ------------------------------------------------------------------------------
cat > "$ROOTFS/etc/local.d/00-crudeos-setup.start" <<'USERINIT'
#!/bin/sh
set -e

# Create default live user if missing
if ! id crudeos >/dev/null 2>&1; then
    adduser -D -s /bin/sh -g "CrudeOS User" crudeos
    passwd -d crudeos 2>/dev/null || true
fi

# Add crudeos to essential subsystem groups
for grp in wheel audio video input netdev network plugdev seat disk; do
    getent group "$grp" >/dev/null 2>&1 || addgroup -S "$grp" 2>/dev/null || true
    addgroup crudeos "$grp" 2>/dev/null || true
done

# Ensure home ownership
mkdir -p /home/crudeos
cp -rT /etc/skel /home/crudeos 2>/dev/null || true
chown -R crudeos:crudeos /home/crudeos
chmod 750 /home/crudeos

# Enable passwordless sudo for live session
echo "crudeos ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/crudeos
chmod 0440 /etc/sudoers.d/crudeos
USERINIT
chmod 755 "$ROOTFS/etc/local.d/00-crudeos-setup.start"

# ------------------------------------------------------------------------------
# Wallpaper: CrudeOS Aqua Minimal Glass Vector (SVG)
# ------------------------------------------------------------------------------
cat > "$ROOTFS/usr/share/backgrounds/crudeos/crudeos-aqua.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3840 2160" width="3840" height="2160">
  <defs>
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0b0d13" />
      <stop offset="50%" stop-color="#10141d" />
      <stop offset="100%" stop-color="#080a0f" />
    </linearGradient>
    <radialGradient id="glow1" cx="35%" cy="40%" r="50%">
      <stop offset="0%" stop-color="#00d2ff" stop-opacity="0.18" />
      <stop offset="60%" stop-color="#0055ff" stop-opacity="0.04" />
      <stop offset="100%" stop-color="#000000" stop-opacity="0" />
    </radialGradient>
    <radialGradient id="glow2" cx="70%" cy="65%" r="45%">
      <stop offset="0%" stop-color="#00ffcc" stop-opacity="0.12" />
      <stop offset="50%" stop-color="#0284c7" stop-opacity="0.03" />
      <stop offset="100%" stop-color="#000000" stop-opacity="0" />
    </radialGradient>
    <linearGradient id="wave1" x1="0%" y1="30%" x2="100%" y2="70%">
      <stop offset="0%" stop-color="#00c6ff" stop-opacity="0.22" />
      <stop offset="50%" stop-color="#0072ff" stop-opacity="0.08" />
      <stop offset="100%" stop-color="#0f172a" stop-opacity="0.0" />
    </linearGradient>
    <linearGradient id="wave2" x1="100%" y1="20%" x2="0%" y2="80%">
      <stop offset="0%" stop-color="#38bdf8" stop-opacity="0.15" />
      <stop offset="60%" stop-color="#6366f1" stop-opacity="0.05" />
      <stop offset="100%" stop-color="#020617" stop-opacity="0.0" />
    </linearGradient>
  </defs>

  <!-- Deep Canvas -->
  <rect width="3840" height="2160" fill="url(#bgGrad)" />
  <rect width="3840" height="2160" fill="url(#glow1)" />
  <rect width="3840" height="2160" fill="url(#glow2)" />

  <!-- Fluid Aqua Ribbon Waves -->
  <path d="M0,900 C600,600 1200,1200 1920,850 C2640,500 3200,1100 3840,800 L3840,2160 L0,2160 Z" fill="url(#wave1)" />
  <path d="M0,1300 C800,1050 1400,1600 2200,1250 C2900,950 3400,1400 3840,1200 L3840,2160 L0,2160 Z" fill="url(#wave2)" />

  <!-- Center Minimal Aqua Emblem -->
  <g transform="translate(1920, 1080)">
    <circle r="72" fill="#00d2ff" fill-opacity="0.06" stroke="#38bdf8" stroke-width="1.5" stroke-opacity="0.35" />
    <circle r="44" fill="#0284c7" fill-opacity="0.10" stroke="#00e5ff" stroke-width="1.5" stroke-opacity="0.6" />
    <path d="M-14,0 A14,14 0 1,1 14,0 A14,14 0 1,1 -14,0" fill="#38bdf8" fill-opacity="0.9" />
  </g>
</svg>
SVG

# ------------------------------------------------------------------------------
# GTK 3 & 4 Theme Overrides (CrudeOS Aqua Design System)
# ------------------------------------------------------------------------------
cat > "$ROOTFS/etc/xdg/gtk-3.0/gtk.css" <<'GTKCSS'
/* ==========================================================================
   CrudeOS Aqua — GTK3/4 Stylesheet
   macOS aesthetic: Frosted dark glass, pill controls, subtle Aqua accents
   ========================================================================== */

@define-color crude_bg #0f1218;
@define-color crude_surface rgba(22, 27, 36, 0.94);
@define-color crude_surface_alt rgba(31, 38, 51, 0.88);
@define-color crude_glass rgba(255, 255, 255, 0.05);
@define-color crude_glass_border rgba(255, 255, 255, 0.08);
@define-color crude_accent #00c2ff;
@define-color crude_accent_hover #38d3ff;
@define-color crude_text #f1f5f9;
@define-color crude_text_muted #94a3b8;

/* Global Window Geometry */
window, dialog {
    background-color: @crude_bg;
    color: @crude_text;
    border-radius: 12px;
}

/* Headerbars & Titlebars */
headerbar {
    min-height: 38px;
    background-color: @crude_surface;
    border-bottom: 1px solid @crude_glass_border;
    border-radius: 12px 12px 0 0;
    padding: 0 10px;
    box-shadow: none;
}

headerbar .title {
    font-weight: 600;
    color: @crude_text;
}

headerbar .subtitle {
    color: @crude_text_muted;
    font-size: 85%;
}

/* Buttons */
button {
    background-color: @crude_glass;
    color: @crude_text;
    border: 1px solid @crude_glass_border;
    border-radius: 8px;
    min-height: 28px;
    padding: 3px 14px;
    transition: all 120ms ease;
}

button:hover {
    background-color: rgba(255, 255, 255, 0.10);
    border-color: rgba(0, 194, 255, 0.4);
}

button:active, button:checked {
    background-color: @crude_accent;
    color: #040d1a;
    border-color: @crude_accent;
}

/* Text Inputs & Searchbars */
entry {
    background-color: rgba(10, 13, 18, 0.7);
    color: @crude_text;
    border: 1px solid @crude_glass_border;
    border-radius: 8px;
    min-height: 30px;
    padding: 4px 10px;
    transition: border-color 150ms ease;
}

entry:focus {
    border-color: @crude_accent;
    box-shadow: 0 0 0 2px rgba(0, 194, 255, 0.2);
}

/* Menus & Popovers */
popover, .menu, menu, .context-menu {
    background-color: @crude_surface;
    border: 1px solid @crude_glass_border;
    border-radius: 10px;
    padding: 6px;
    box-shadow: 0 10px 24px rgba(0, 0, 0, 0.45);
}

menuitem {
    border-radius: 6px;
    padding: 5px 12px;
    color: @crude_text;
    transition: background-color 80ms ease;
}

menuitem:hover {
    background-color: @crude_accent;
    color: #040d1a;
}

/* Scrollbars */
scrollbar {
    background: transparent;
}

scrollbar slider {
    background-color: rgba(255, 255, 255, 0.18);
    border-radius: 999px;
    min-width: 6px;
    min-height: 6px;
    margin: 3px;
    transition: background-color 150ms;
}

scrollbar slider:hover {
    background-color: @crude_accent;
}

/* Switches */
switch {
    border-radius: 999px;
    background-color: rgba(255, 255, 255, 0.12);
}

switch:checked {
    background-color: @crude_accent;
}

switch slider {
    border-radius: 999px;
    background-color: #ffffff;
    min-width: 18px;
    min-height: 18px;
}

/* XFCE Top Bar (Panel 1) */
#xfce4-panel-1, .xfce4-panel-1 {
    background-color: rgba(13, 17, 23, 0.88);
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
}

/* XFCE Bottom Dock (Panel 2) */
#xfce4-panel-2, .xfce4-panel-2 {
    background-color: rgba(18, 22, 30, 0.82);
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 20px;
    box-shadow: 0 12px 30px rgba(0, 0, 0, 0.4);
}

/* Docklike Plugin styling inside Panel 2 */
#xfce4-panel-2 button {
    border-radius: 12px;
    background: transparent;
    border: none;
    padding: 2px 6px;
    margin: 2px 3px;
}

#xfce4-panel-2 button:hover {
    background-color: rgba(255, 255, 255, 0.12);
}

#xfce4-panel-2 button:checked {
    background-color: rgba(0, 194, 255, 0.22);
    border-bottom: 2px solid @crude_accent;
}

/* Whisker Menu */
#whiskermenu-window {
    background-color: rgba(15, 19, 26, 0.96);
    border: 1px solid @crude_glass_border;
    border-radius: 14px;
    padding: 10px;
}
GTKCSS

# Mirror to GTK-4.0 & User Skel
cp "$ROOTFS/etc/xdg/gtk-3.0/gtk.css" "$ROOTFS/etc/xdg/gtk-4.0/gtk.css"
cp "$ROOTFS/etc/xdg/gtk-3.0/gtk.css" "$SKEL/.config/gtk-3.0/gtk.css"
cp "$ROOTFS/etc/xdg/gtk-3.0/gtk.css" "$SKEL/.config/gtk-4.0/gtk.css"

# ------------------------------------------------------------------------------
# User GTK Settings (Settings.ini)
# ------------------------------------------------------------------------------
cat > "$SKEL/.config/gtk-3.0/settings.ini" <<'GTKINI'
[Settings]
gtk-theme-name = adw-gtk3-dark
gtk-icon-theme-name = Papirus-Dark
gtk-font-name = Inter 10
gtk-cursor-theme-name = Adwaita
gtk-application-prefer-dark-theme = true
gtk-enable-animations = true
gtk-decoration-layout = close,minimize,maximize:
gtk-xft-antialias = 1
gtk-xft-hinting = 1
gtk-xft-hintstyle = hintslight
gtk-xft-rgba = rgb
GTKINI
cp "$SKEL/.config/gtk-3.0/settings.ini" "$SKEL/.config/gtk-4.0/settings.ini"

# ------------------------------------------------------------------------------
# Picom Compositor Configuration (Optimized for 120Hz VSync & Smooth Polish)
# ------------------------------------------------------------------------------
cat > "$ROOTFS/etc/xdg/picom/picom.conf" <<'PICOM'
# CrudeOS Aqua Compositor Configuration

# Backend
backend = "glx";
glx-no-stencil = true;
glx-copy-from-front = false;

# Refresh rate & VSync
vsync = true;
use-damage = true;
unredir-if-possible = true;

# Rounded Corners
corner-radius = 12;
rounded-corners-exclude = [
  "window_type = 'desktop'",
  "class_g = 'Xfce4-panel'",
  "window_type = 'dock'"
];

# Subtle Glass Shadows
shadow = true;
shadow-radius = 16;
shadow-opacity = 0.35;
shadow-offset-x = -16;
shadow-offset-y = -16;
shadow-exclude = [
  "name = 'Notification'",
  "class_g = 'Xfce4-notifyd'",
  "class_g = 'Xfce4-panel'",
  "_GTK_FRAME_EXTENTS@:c"
];

# Smooth Window Animations & Fading
fading = true;
fade-in-step = 0.04;
fade-out-step = 0.04;
fade-delta = 6;
no-fading-openclose = false;

# Opacity
active-opacity = 1.0;
inactive-opacity = 0.96;
frame-opacity = 1.0;
inactive-opacity-override = false;

# Window Types
wintypes:
{
  tooltip = { fade = true; shadow = false; opacity = 0.95; focus = true; };
  dock = { shadow = false; clip-shadow-above = true; };
  dnd = { shadow = false; };
  popup_menu = { opacity = 0.98; fade = true; };
  dropdown_menu = { opacity = 0.98; fade = true; };
};
PICOM

# Picom Autostart
cat > "$ROOTFS/etc/xdg/autostart/crudeos-picom.desktop" <<'AUTOSTART'
[Desktop Entry]
Type=Application
Name=Picom Compositor
Comment=CrudeOS 120Hz VSync Compositor
Exec=picom --config /etc/xdg/picom/picom.conf -b
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
AUTOSTART

# ------------------------------------------------------------------------------
# Custom XFWM4 Theme: CrudeOS-Aqua (macOS Traffic Light Buttons)
# ------------------------------------------------------------------------------
# Generates clean, modern window decoration metrics and buttons
XFWM_DIR="$ROOTFS/usr/share/themes/CrudeOS-Aqua/xfwm4"
cat > "$XFWM_DIR/themerc" <<'THEMERC'
button_spacing=6
button_offset=8
maximized_offset=8
title_alignment=center
title_font=Inter Bold 10
title_shadow_active=false
title_shadow_inactive=false
active_text_color=#f1f5f9
inactive_text_color=#64748b
active_color_1=#141820
inactive_color_1=#101319
full_width_title=true
THEMERC

# Generate minimal modern dot buttons (active/inactive)
gen_xpm() {
    file="$1"
    color="$2"
    border="$3"
    cat > "$file" <<XPM
/* XPM */
static char * btn[] = {
"16 16 3 1",
"  c None",
". c ${border}",
"+ c ${color}",
"                ",
"     ......     ",
"   ..++++++..   ",
"  .++++++++++.  ",
" .++++++++++++. ",
" .++++++++++++. ",
".++++++++++++++.",
".++++++++++++++.",
".++++++++++++++.",
".++++++++++++++.",
" .++++++++++++. ",
" .++++++++++++. ",
"  .++++++++++.  ",
"   ..++++++..   ",
"     ......     ",
"                "
};
XPM
}

gen_bar_xpm() {
    file="$1"
    color="$2"
    cat > "$file" <<XPM
/* XPM */
static char * bar[] = {
"1 30 1 1",
". c ${color}",
".",".",".",".",".",".",".",".",".",".",
".",".",".",".",".",".",".",".",".",".",
".",".",".",".",".",".",".",".",".","."
};
XPM
}

# Red (close), Yellow (minimize), Green (maximize)
gen_xpm "$XFWM_DIR/close-active.xpm" "#ff5f57" "#e0443e"
gen_xpm "$XFWM_DIR/close-inactive.xpm" "#525866" "#3c414c"
gen_xpm "$XFWM_DIR/close-prelight.xpm" "#ff736b" "#ff5f57"

gen_xpm "$XFWM_DIR/hide-active.xpm" "#febc2e" "#d89e24"
gen_xpm "$XFWM_DIR/hide-inactive.xpm" "#525866" "#3c414c"
gen_xpm "$XFWM_DIR/hide-prelight.xpm" "#ffcf52" "#febc2e"

gen_xpm "$XFWM_DIR/maximize-active.xpm" "#28c840" "#1aab2f"
gen_xpm "$XFWM_DIR/maximize-inactive.xpm" "#525866" "#3c414c"
gen_xpm "$XFWM_DIR/maximize-prelight.xpm" "#34e04e" "#28c840"

for bar in title-1 title-2 title-3 title-4 title-5 top-left top-right; do
    gen_bar_xpm "$XFWM_DIR/${bar}-active.xpm" "#141820"
    gen_bar_xpm "$XFWM_DIR/${bar}-inactive.xpm" "#101319"
done

# ------------------------------------------------------------------------------
# XFWM4 Configuration
# ------------------------------------------------------------------------------
cat > "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" <<'XFWM'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="CrudeOS-Aqua"/>
    <property name="button_layout" type="string" value="CHM|"/>
    <property name="title_alignment" type="string" value="center"/>
    <property name="use_compositing" type="bool" value="false"/>
    <property name="vblank_mode" type="string" value="glx"/>
    <property name="box_resize" type="bool" value="false"/>
    <property name="box_move" type="bool" value="false"/>
    <property name="cycle_draw_box" type="bool" value="false"/>
    <property name="cycle_tabwin_mode" type="int" value="1"/>
    <property name="workspace_count" type="int" value="4"/>
    <property name="wrap_workspaces" type="bool" value="false"/>
    <property name="wrap_windows" type="bool" value="false"/>
    <property name="snap_to_border" type="bool" value="true"/>
    <property name="snap_to_windows" type="bool" value="true"/>
    <property name="snap_width" type="int" value="10"/>
  </property>
</channel>
XFWM

# ------------------------------------------------------------------------------
# XFCE Panel (Panel 1: Sleek Top Bar | Panel 2: Centered Floating Dock)
# ------------------------------------------------------------------------------
cat > "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" <<'PANEL'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <value type="int" value="2"/>
    <!-- Top Bar -->
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="30"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="6"/>
        <value type="int" value="7"/>
        <value type="int" value="8"/>
        <value type="int" value="9"/>
      </property>
    </property>
    <!-- Centered Dock -->
    <property name="panel-2" type="empty">
      <property name="position" type="string" value="p=10;x=0;y=10"/>
      <property name="length" type="uint" value="45"/>
      <property name="length-adjust" type="bool" value="true"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="56"/>
      <property name="autohide-behavior" type="uint" value="1"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="10"/>
      </property>
    </property>
  </property>

  <!-- Plugin IDs mapping -->
  <property name="plugins" type="empty">
    <!-- Top Left -->
    <property name="plugin-1" type="string" value="whiskermenu"/>
    <property name="plugin-2" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-3" type="string" value="pager"/>
    <property name="plugin-4" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <!-- Top Right Status Tray -->
    <property name="plugin-5" type="string" value="systray">
      <property name="square-icons" type="bool" value="true"/>
    </property>
    <property name="plugin-6" type="string" value="pulseaudio"/>
    <property name="plugin-7" type="string" value="power-manager-plugin"/>
    <property name="plugin-8" type="string" value="notification-plugin"/>
    <property name="plugin-9" type="string" value="clock">
      <property name="digital-format" type="string" value="%a %b %d  %I:%M %p"/>
    </property>
    <!-- Docklike Bottom Plugin -->
    <property name="plugin-10" type="string" value="docklike">
      <property name="grouping" type="uint" value="1"/>
      <property name="show-label" type="bool" value="false"/>
      <property name="icon-size" type="uint" value="40"/>
      <property name="indicator-style" type="uint" value="1"/>
      <property name="indicator-color" type="string" value="#00c2ff"/>
      <property name="pinned-apps" type="array">
        <value type="string" value="firefox-esr.desktop"/>
        <value type="string" value="thunar.desktop"/>
        <value type="string" value="xfce4-terminal.desktop"/>
        <value type="string" value="mousepad.desktop"/>
        <value type="string" value="xfce4-taskmanager.desktop"/>
        <value type="string" value="xfce4-settings-manager.desktop"/>
      </property>
    </property>
  </property>
</channel>
PANEL

# ------------------------------------------------------------------------------
# Whisker Menu Configuration
# ------------------------------------------------------------------------------
cat > "$SKEL/.config/xfce4/panel/whiskermenu-1.rc" <<'WHISKER'
favorites=firefox-esr.desktop,thunar.desktop,xfce4-terminal.desktop,mousepad.desktop,xfce4-settings-manager.desktop
button-title=CrudeOS
button-icon=start-here
show-button-title=true
show-button-icon=true
launcher-show-name=true
launcher-show-description=true
category-icon-size=1
item-icon-size=2
hover-switch-category=true
position-search-alternate=true
WHISKER

# ------------------------------------------------------------------------------
# Rofi Spotlight Launcher (CrudeOS Spotlight Style)
# ------------------------------------------------------------------------------
cat > "$SKEL/.config/rofi/config.rasi" <<'ROFI'
configuration {
    modi: "drun,run";
    font: "Inter 11";
    show-icons: true;
    icon-theme: "Papirus-Dark";
    display-drun: "Search Apps";
    drun-display-format: "{name}";
}

@theme "/dev/null"

* {
    bg: rgba(18, 22, 30, 0.92);
    fg: #f1f5f9;
    fg-muted: #94a3b8;
    accent: #00c2ff;
    border-col: rgba(255, 255, 255, 0.12);
    background-color: transparent;
    text-color: @fg;
}

window {
    width: 600px;
    border-radius: 16px;
    border: 1px solid @border-col;
    background-color: @bg;
    padding: 16px;
    location: center;
    anchor: center;
    y-offset: -120px;
}

inputbar {
    children: [prompt, entry];
    background-color: rgba(255, 255, 255, 0.06);
    border: 1px solid @border-col;
    border-radius: 10px;
    padding: 10px 14px;
    margin: 0 0 12px 0;
}

prompt {
    text-color: @accent;
    font: "Inter Bold 11";
    margin: 0 8px 0 0;
}

entry {
    placeholder: "Type to launch application or file...";
    placeholder-color: @fg-muted;
}

listview {
    lines: 7;
    columns: 1;
    scrollbar: false;
    spacing: 4px;
}

element {
    padding: 8px 12px;
    border-radius: 8px;
    children: [element-icon, element-text];
    spacing: 12px;
}

element selected {
    background-color: @accent;
    text-color: #040d1a;
}

element-icon {
    size: 24px;
}

element-text {
    vertical-align: 0.5;
}
ROFI

# Bind Super Key to Rofi Spotlight
cat > "$ROOTFS/usr/local/bin/crudeos-spotlight" <<'SPOTLIGHT'
#!/bin/sh
exec rofi -show drun
SPOTLIGHT
chmod +x "$ROOTFS/usr/local/bin/crudeos-spotlight"

# ------------------------------------------------------------------------------
# CrudeOS Session Initialization Script
# ------------------------------------------------------------------------------
cat > "$ROOTFS/usr/local/bin/crudeos-session-init" <<'SESSIONINIT'
#!/bin/sh

# Set XSETTINGS globally for active session
xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s "adw-gtk3-dark" 2>/dev/null || true
xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s "Papirus-Dark" 2>/dev/null || true
xfconf-query -c xsettings -p /Gtk/FontName -n -t string -s "Inter 10" 2>/dev/null || true
xfconf-query -c xsettings -p /Gtk/MonospaceFontName -n -t string -s "Monospace 10" 2>/dev/null || true
xfconf-query -c xsettings -p /Gtk/CursorThemeName -n -t string -s "Adwaita" 2>/dev/null || true

# Set CrudeOS Aqua Wallpaper across all monitors and workspaces
BG="/usr/share/backgrounds/crudeos/crudeos-aqua.svg"
if command -v feh >/dev/null 2>&1; then
    feh --bg-fill "$BG" 2>/dev/null || true
fi

for prop in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep "last-image"); do
    xfconf-query -c xfce4-desktop -p "$prop" -s "$BG" 2>/dev/null || true
done
for prop in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep "image-style"); do
    xfconf-query -c xfce4-desktop -p "$prop" -s 5 2>/dev/null || true
done

# Start user-level PipeWire and WirePlumber if not already active
if command -v pipewire >/dev/null 2>&1; then
    pgrep -x pipewire >/dev/null || pipewire &
    pgrep -x pipewire-pulse >/dev/null || pipewire-pulse &
    pgrep -x wireplumber >/dev/null || wireplumber &
fi

# Start NetworkManager applet
if command -v nm-applet >/dev/null 2>&1; then
    pgrep -x nm-applet >/dev/null || nm-applet &
fi

exit 0
SESSIONINIT
chmod +x "$ROOTFS/usr/local/bin/crudeos-session-init"

# Register autostart for session init
cat > "$ROOTFS/etc/xdg/autostart/crudeos-session-init.desktop" <<'AUTOSTART'
[Desktop Entry]
Type=Application
Name=CrudeOS Session Setup
Exec=/usr/local/bin/crudeos-session-init
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
AUTOSTART

# ------------------------------------------------------------------------------
# System Branding (/etc/os-release & /etc/motd)
# ------------------------------------------------------------------------------
cat > "$ROOTFS/etc/os-release" <<EOF
NAME="CrudeOS"
ID=crudeos
ID_LIKE=alpine
PRETTY_NAME="CrudeOS ${CRUDEOS_VERSION} (${CRUDEOS_CODENAME})"
VERSION_ID="${CRUDEOS_VERSION}"
VERSION="${CRUDEOS_VERSION} (${CRUDEOS_CODENAME})"
HOME_URL="https://github.com/Dev-Mehraj/Project14"
BUG_REPORT_URL="https://github.com/Dev-Mehraj/Project14/issues"
EOF

cat > "\$ROOTFS/etc/issue" <<'ISSUE'
CrudeOS Aqua \r (\l) - Live Session
ISSUE

echo "[install-gui] CrudeOS Aqua GUI assets generated successfully."
EOF
chmod +x "$WORK/install-crudeos-gui.sh"

# ------------------------------------------------------------------------------
# 5. Build ISO inside Alpine Container
# ------------------------------------------------------------------------------
echo
echo "[1/4] Pulling container image: $CONTAINER_IMAGE..."
"$RUNTIME" pull "$CONTAINER_IMAGE"

echo
echo "[2/4] Executing Alpine mkimage container build..."
"$RUNTIME" run --rm --privileged \
    -e APORTS_TAG="$ALPINE_BRANCH" \
    -e CRUDEOS_VERSION="$CRUDEOS_VERSION" \
    -e CRUDEOS_CODENAME="$CRUDEOS_CODENAME" \
    -e CRUDEOS_ARCH="$ARCH" \
    -v "$WORK:/work" \
    "$CONTAINER_IMAGE" \
    /bin/sh -c '
set -eu

echo "[container] Installing toolchain & aports dependencies..."
apk update
apk add --no-cache \
    alpine-sdk \
    alpine-conf \
    abuild \
    syslinux \
    xorriso \
    squashfs-tools \
    grub \
    grub-efi \
    mtools \
    dosfstools \
    git

mkdir -p /work/aports /work/out /work/work

echo "[container] Fetching Alpine aports branch: $APORTS_TAG..."
if [ ! -d /work/aports/.git ]; then
    git clone --depth=1 --branch "$APORTS_TAG" \
        https://gitlab.alpinelinux.org/alpine/aports.git /work/aports
fi

echo "[container] Installing CrudeOS profile and hooks..."
cp /work/profile_crudeos.sh /work/aports/scripts/mkimg.crudeos.sh
cp /work/genapkovl-crudeos.sh /work/aports/scripts/genapkovl-crudeos.sh
chmod +x /work/aports/scripts/mkimg.crudeos.sh \
         /work/aports/scripts/genapkovl-crudeos.sh

echo "[container] Setting up abuild cryptographic key..."
mkdir -p /root/.abuild
if ! find /etc/apk/keys -maxdepth 1 -type f -name "*.rsa.pub" 2>/dev/null | grep -q .; then
    abuild-keygen -ain
fi

echo "[container] Running Alpine mkimage.sh..."
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

echo "[container] Build completed. Output files:"
find /work/out -maxdepth 1 -type f -name "*.iso"
'

# ------------------------------------------------------------------------------
# 6. Artifact Verification & Checksum
# ------------------------------------------------------------------------------
echo
echo "[3/4] Locating generated ISO image..."
ISO=""
while IFS= read -r candidate; do
    ISO="$candidate"
    break
done < <(find "$WORK/out" -maxdepth 1 -type f -iname "*.iso" | sort)

[ -n "$ISO" ] || die "mkimage completed but no ISO was found in $WORK/out."

FINAL="$OUT/crudeos-${CRUDEOS_VERSION}-${ARCH}.iso"
cp -f "$ISO" "$FINAL"

echo
echo "[4/4] Computing SHA256 verification hash..."
sha256sum "$FINAL" | tee "$FINAL.sha256"

echo
echo "============================================================"
echo " CrudeOS Aqua Desktop ISO Created Successfully!"
echo " Output : $FINAL"
echo " SHA256 : $(cat "$FINAL.sha256" | awk '{print $1}')"
echo "============================================================"
echo
echo "To test in QEMU with KVM:"
echo "  qemu-system-x86_64 -enable-kvm -m 4096 -smp 4 -vga virtio -display gtk,gl=on -cdrom \"$FINAL\""
echo
echo "To test with UEFI:"
echo "  qemu-system-x86_64 -enable-kvm -m 4096 -bios /usr/share/ovmf/OVMF.fd -cdrom \"$FINAL\""
echo "============================================================"
