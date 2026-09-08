#!/usr/bin/env bash
# ============================================================
#                    CrudeOS ISO Builder
# ============================================================
#
# CrudeOS is an Alpine Linux-based desktop distribution.
#
# Included GUI:
#   - XFCE
#   - Whisker Menu
#   - Docklike taskbar/dock
#   - Picom compositor + VSync
#   - Adw-gtk3 dark theme
#   - GTK CSS customization
#   - NetworkManager
#   - PipeWire
#   - Firefox ESR
#
# Host requirements:
#   - Docker OR Podman
#
# Build:
#   chmod +x build_crude_os.sh
#   ./build_crude_os.sh
#
# Optional:
#   CRUDEOS_VERSION=1.0.0 ./build_crude_os.sh
#
# Output:
#   dist/crudeos-<version>-x86_64.iso
#
# ============================================================

set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK="$ROOT/.crudeos-build"
OUT="$ROOT/dist"

ALPINE_VERSION="${ALPINE_VERSION:-3.24.1}"
ALPINE_BRANCH="${ALPINE_BRANCH:-v3.24}"

CRUDEOS_VERSION="${CRUDEOS_VERSION:-1.0.0}"
CRUDEOS_CODENAME="${CRUDEOS_CODENAME:-Forge}"

ARCH="${ARCH:-x86_64}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-alpine:${ALPINE_VERSION}}"

mkdir -p "$WORK" "$OUT"

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

die() {
    echo
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

# ============================================================
# FILE 1: packages.txt
# ============================================================

cat > "$WORK/packages.txt" <<'EOF'
alpine-base
linux-lts
linux-firmware

# XFCE core
xfce4
xfce4-panel
xfce4-session
xfce4-settings
xfwm4
thunar
thunar-volman
tumbler

# CrudeOS Aqua GUI
xfce4-docklike-plugin
xfce4-whiskermenu-plugin
xfce4-pulseaudio-plugin
xfce4-statusnotifier-plugin
xfce4-power-manager
xfce4-screenshooter
xfce4-taskmanager
xfce4-terminal
xfce4-notifyd
xfce-polkit

# Themes / icons / compositor
adw-gtk3
adwaita-xfce-icon-theme
picom

# Display / session / hardware
dbus
dbus-x11
elogind
polkit-elogind
libinput
xf86-input-libinput

# Graphics
mesa-dri-gallium
mesa-egl
mesa-gl
xf86-video-amdgpu
xf86-video-intel
xf86-video-nouveau

# Networking
networkmanager
network-manager-applet

# Audio
pipewire
pipewire-pulse
wireplumber
pavucontrol
alsa-utils

# Applications
xarchiver
mousepad
ristretto
htop
git
curl
firefox-esr
EOF

# ============================================================
# FILE 2: aqua-profile.sh
# ============================================================

cat > "$WORK/aqua-profile.sh" <<'EOF'
#!/bin/sh

# CrudeOS Aqua mkimage profile

profile_crudeos()
{
    profile_standard

    title="CrudeOS"
    desc="CrudeOS - Lightweight Alpine-based desktop"

    kernel_flavors="lts"

    apks="$apks
        $(grep -v '^#' /work/packages.txt | sed '/^[[:space:]]*$/d')
    "

    apkovl="genapkovl-crudeos.sh"

    kernel_cmdline="$kernel_cmdline quiet loglevel=3"
}
EOF

chmod +x "$WORK/aqua-profile.sh"

# ============================================================
# FILE 3: theme.css
# ============================================================

cat > "$WORK/theme.css" <<'EOF'
/*
 * ============================================================
 *                 CRUDEOS AQUA GTK THEME
 * ============================================================
 *
 * Lightweight macOS-inspired styling.
 *
 * This deliberately avoids giant shadows / expensive blur.
 * The compositor handles transparency separately.
 */

/* ------------------------------------------------------------
   Main surfaces
   ------------------------------------------------------------ */

window,
dialog,
.background
{
    border-radius: 14px;
}

/* ------------------------------------------------------------
   Header bars
   ------------------------------------------------------------ */

headerbar
{
    min-height: 40px;
    border-radius: 14px 14px 0 0;
}

/* ------------------------------------------------------------
   Buttons
   ------------------------------------------------------------ */

button
{
    border-radius: 10px;
    min-height: 32px;
    padding-left: 12px;
    padding-right: 12px;
}

/* ------------------------------------------------------------
   Entries
   ------------------------------------------------------------ */

entry
{
    border-radius: 10px;
    min-height: 34px;
}

/* ------------------------------------------------------------
   Menus / popovers
   ------------------------------------------------------------ */

popover,
.menu,
.context-menu
{
    border-radius: 12px;
}

/* ------------------------------------------------------------
   Scrollbars
   ------------------------------------------------------------ */

scrollbar slider
{
    border-radius: 8px;
    min-width: 7px;
    min-height: 7px;
}

/* ------------------------------------------------------------
   CrudeOS accent elements
   ------------------------------------------------------------ */

.link-button
{
    border-radius: 9px;
}

/* ------------------------------------------------------------
   Tooltips
   ------------------------------------------------------------ */

tooltip
{
    border-radius: 9px;
}
EOF

# ============================================================
# FILE 4: install-crudeos-aqua-gui.sh
# ============================================================

cat > "$WORK/install-crudeos-aqua-gui.sh" <<'EOF'
#!/bin/sh

set -eu

ROOTFS="${1:-/}"

GUI_DIR="$ROOTFS/etc/crudeos-gui"

mkdir -p "$GUI_DIR"
mkdir -p "$ROOTFS/etc/xdg/picom"
mkdir -p "$ROOTFS/etc/xdg/autostart"

mkdir -p "$ROOTFS/etc/xdg/gtk-3.0"
mkdir -p "$ROOTFS/etc/xdg/gtk-4.0"

mkdir -p "$ROOTFS/etc/skel/.config/gtk-3.0"
mkdir -p "$ROOTFS/etc/skel/.config/gtk-4.0"

mkdir -p \
    "$ROOTFS/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"

# ============================================================
# Package manifest
# ============================================================

cp /work/packages.txt \
   "$GUI_DIR/packages.txt"

# ============================================================
# GTK CSS
# ============================================================

cp /work/theme.css \
   "$ROOTFS/etc/xdg/gtk-3.0/crudeos-aqua.css"

cp /work/theme.css \
   "$ROOTFS/etc/xdg/gtk-4.0/crudeos-aqua.css"

# ============================================================
# GTK settings
# ============================================================

cat > "$ROOTFS/etc/skel/.config/gtk-3.0/settings.ini" <<'GTK3'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=DejaVu Sans 10
gtk-application-prefer-dark-theme=true
gtk-enable-animations=true
gtk-decoration-layout=close,minimize,maximize:
gtk-primary-button-warps-slider=false
gtk-enable-event-sounds=false
gtk-enable-input-feedback-sounds=false
GTK3

cat > "$ROOTFS/etc/skel/.config/gtk-4.0/settings.ini" <<'GTK4'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=DejaVu Sans 10
gtk-application-prefer-dark-theme=true
gtk-enable-animations=true
GTK4

# ============================================================
# Picom compositor
# ============================================================

cat > "$ROOTFS/etc/xdg/picom/picom.conf" <<'PICOM'
backend = "glx";

# Synchronize compositor output with the display.
vsync = true;

use-damage = true;

# ------------------------------------------------------------
# Lightweight effects
# ------------------------------------------------------------

shadow = false;

fading = true;

fade-in-step = 0.03;
fade-out-step = 0.03;
fade-delta = 8;

# ------------------------------------------------------------
# Transparency
# ------------------------------------------------------------

active-opacity = 1.0;
inactive-opacity = 0.94;
frame-opacity = 0.96;

# Disable expensive blur.
blur-background = false;

# ------------------------------------------------------------
# Window types
# ------------------------------------------------------------

wintypes:
{
    tooltip =
    {
        fade = true;
        shadow = false;
    };

    dock =
    {
        shadow = false;
    };

    popup_menu =
    {
        fade = true;
    };

    dropdown_menu =
    {
        fade = true;
    };
};
PICOM

# ============================================================
# Picom autostart
# ============================================================

cat > "$ROOTFS/etc/xdg/autostart/crudeos-picom.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=CrudeOS Compositor
Comment=Lightweight synchronized compositor
Exec=picom --config /etc/xdg/picom/picom.conf
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESKTOP

# ============================================================
# XFWM configuration
# ============================================================

cat > \
"$ROOTFS/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" \
<<'XFWM'
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfwm4" version="1.0">

    <property name="general" type="empty">

        <!-- Picom handles compositing -->
        <property
            name="use_compositing"
            type="bool"
            value="false"
        />

        <!-- GPU synchronized rendering -->
        <property
            name="vblank_mode"
            type="string"
            value="glx"
        />

        <!-- Center window titles -->
        <property
            name="title_alignment"
            type="string"
            value="center"
        />

        <!-- macOS-like title controls -->
        <property
            name="button_layout"
            type="string"
            value="O|HMC"
        />

        <property
            name="frame_opacity"
            type="int"
            value="100"
        />

        <property
            name="inactive_opacity"
            type="int"
            value="94"
        />

    </property>

</channel>
XFWM

# ============================================================
# CrudeOS desktop startup
# ============================================================

cat > "$ROOTFS/etc/xdg/autostart/crudeos-aqua.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=CrudeOS Aqua
Comment=CrudeOS desktop environment setup
Exec=/usr/local/bin/crudeos-aqua-init
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
NoDisplay=true
DESKTOP

cat > "$ROOTFS/usr/local/bin/crudeos-aqua-init" <<'INIT'
#!/bin/sh

# Wait for xfconf to be available.
sleep 1

# ------------------------------------------------------------
# GTK / icon theme
# ------------------------------------------------------------

xfconf-query \
    -c xsettings \
    -p /Net/ThemeName \
    -n -t string \
    -s "adw-gtk3-dark" \
    2>/dev/null || true

xfconf-query \
    -c xsettings \
    -p /Net/IconThemeName \
    -n -t string \
    -s "Adwaita" \
    2>/dev/null || true

xfconf-query \
    -c xsettings \
    -p /Gtk/FontName \
    -n -t string \
    -s "DejaVu Sans 10" \
    2>/dev/null || true

# ------------------------------------------------------------
# XFWM
# ------------------------------------------------------------

xfconf-query \
    -c xfwm4 \
    -p /general/use_compositing \
    -n -t bool \
    -s false \
    2>/dev/null || true

xfconf-query \
    -c xfwm4 \
    -p /general/vblank_mode \
    -n -t string \
    -s glx \
    2>/dev/null || true

# ------------------------------------------------------------
# Start NetworkManager applet
# ------------------------------------------------------------

if command -v nm-applet >/dev/null 2>&1; then
    nm-applet >/dev/null 2>&1 &
fi

exit 0
INIT

chmod +x "$ROOTFS/usr/local/bin/crudeos-aqua-init"

# ============================================================
# CrudeOS system identity
# ============================================================

cat > "$ROOTFS/etc/os-release" <<EOF
NAME="CrudeOS"
ID=crudeos
ID_LIKE=alpine
PRETTY_NAME="CrudeOS ${CRUDEOS_VERSION} (${CRUDEOS_CODENAME})"
VERSION_ID="${CRUDEOS_VERSION}"
VERSION="${CRUDEOS_VERSION} (${CRUDEOS_CODENAME})"
HOME_URL="https://github.com/Dev-Mehraj/Project14"
BUG_REPORT_URL="https://github.com/Dev-Mehraj/Project14/issues"
SUPPORT_URL="https://github.com/Dev-Mehraj/Project14/issues"
EOF

# ============================================================
# Hostname
# ============================================================

cat > "$ROOTFS/etc/hostname" <<'EOF'
crudeos
EOF

# ============================================================
# MOTD
# ============================================================

cat > "$ROOTFS/etc/motd" <<'EOF'

   ____                 _      ____   ____
  / ___|_ __ _   _  __| | ___/ ___| / ___|
 | |   | '__| | | |/ _` |/ _ \___ \| |
 | |___| |  | |_| | (_| |  __/___) | |___
  \____|_|   \__,_|\__,_|\___|____/ \____|

             Welcome to CrudeOS
           Lightweight. Fast. Yours.

EOF

# ============================================================
# Services
# ============================================================

rc_add dbus default 2>/dev/null || true
rc_add elogind default 2>/dev/null || true
rc_add networkmanager default 2>/dev/null || true
rc_add lightdm default 2>/dev/null || true

echo "[CrudeOS GUI] Aqua desktop installed."
EOF

chmod +x "$WORK/install-crudeos-aqua-gui.sh"

# ============================================================
# mkimage profile wrapper
# ============================================================

cat > "$WORK/profile_wrapper.sh" <<'EOF'
#!/bin/sh

profile_crudeos()
{
    profile_standard

    title="CrudeOS"
    desc="CrudeOS - Smooth Aqua XFCE Desktop"

    kernel_flavors="lts"

    apks="$apks
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
        xfce4-statusnotifier-plugin
        xfce4-power-manager
        xfce4-screenshooter
        xfce4-taskmanager
        xfce4-terminal
        xfce4-notifyd
        xfce-polkit

        adw-gtk3
        adwaita-xfce-icon-theme
        picom

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
    "

    apkovl="genapkovl-crudeos.sh"

    kernel_cmdline="$kernel_cmdline quiet loglevel=3"
}
EOF

chmod +x "$WORK/profile_wrapper.sh"

# ============================================================
# apkovl generator
# ============================================================

cat > "$WORK/genapkovl-crudeos.sh" <<'EOF'
#!/bin/sh

set -eu

tmp="$1"

mkdir -p "$tmp"

# Install GUI configuration.
/work/install-crudeos-aqua-gui.sh "$tmp"

# Tell Alpine which packages belong to the final image.
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
xfce4-statusnotifier-plugin
xfce4-power-manager
xfce4-screenshooter
xfce4-taskmanager
xfce4-terminal
xfce4-notifyd
xfce-polkit
adw-gtk3
adwaita-xfce-icon-theme
picom
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
EOF

chmod +x "$WORK/genapkovl-crudeos.sh"

# ============================================================
# Start Alpine build container
# ============================================================

echo
echo "[1/5] Pulling Alpine build container..."
echo

"$RUNTIME" pull "$CONTAINER_IMAGE"

# ============================================================
# Build inside container
# ============================================================

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

echo "[container] Installing image-building tools..."

apk add --no-cache \
    alpine-sdk \
    alpine-conf \
    abuild \
    syslinux \
    xorriso \
    squashfs-tools \
    grub \
    mtools \
    git

mkdir -p \
    /work/aports \
    /work/out \
    /work/work \
    /work/root

echo "[container] Getting Alpine aports..."

if [ ! -d /work/aports/.git ]; then

    git clone \
        --depth=1 \
        --branch "$APORTS_TAG" \
        https://gitlab.alpinelinux.org/alpine/aports.git \
        /work/aports

fi

echo "[container] Installing CrudeOS build files..."

cp /work/profile_wrapper.sh \
   /work/aports/scripts/mkimg.crudeos.sh

cp /work/genapkovl-crudeos.sh \
   /work/aports/scripts/genapkovl-crudeos.sh

cp /work/install-crudeos-aqua-gui.sh \
   /work/aports/scripts/install-crudeos-aqua-gui.sh

cp /work/packages.txt \
   /work/aports/scripts/packages.txt

cp /work/theme.css \
   /work/aports/scripts/theme.css

chmod +x \
    /work/aports/scripts/mkimg.crudeos.sh \
    /work/aports/scripts/genapkovl-crudeos.sh \
    /work/aports/scripts/install-crudeos-aqua-gui.sh

echo "[container] Preparing abuild keys..."

mkdir -p /root/.abuild

if ! find /etc/apk/keys \
    -maxdepth 1 \
    -type f \
    -name "*.rsa.pub" \
    | grep -q .; then

    abuild-keygen -ain

fi

echo
echo "[container] Building CrudeOS ISO..."
echo

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

echo
echo "[container] Generated files:"
echo

find /work/out \
    -maxdepth 1 \
    -type f \
    -printf "%f\n" \
    | sort
'

# ============================================================
# Locate ISO
# ============================================================

echo
echo "[3/5] Locating generated ISO..."
echo

ISO=""

while IFS= read -r candidate; do
    ISO="$candidate"
    break
done < <(
    find "$WORK/out" \
        -maxdepth 1 \
        -type f \
        -iname "*.iso" \
        | sort
)

[ -n "$ISO" ] || die "No ISO was generated."

# ============================================================
# Copy final ISO
# ============================================================

echo
echo "[4/5] Copying final CrudeOS ISO..."
echo

FINAL="$OUT/crudeos-${CRUDEOS_VERSION}-${ARCH}.iso"

cp -f "$ISO" "$FINAL"

# ============================================================
# Checksum
# ============================================================

echo
echo "[5/5] Generating checksum..."
echo

sha256sum "$FINAL" \
    | tee "$FINAL.sha256"

echo
echo "============================================================"
echo "                 CRUDEOS BUILD COMPLETE"
echo "============================================================"
echo
echo " ISO:"
echo " $FINAL"
echo
echo " SHA256:"
cat "$FINAL.sha256"
echo
echo "============================================================"
echo
echo "To test with QEMU:"
echo
echo "  qemu-system-x86_64 -enable-kvm -m 4096 -cdrom \"$FINAL\""
echo
