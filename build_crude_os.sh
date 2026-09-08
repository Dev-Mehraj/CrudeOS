#!/usr/bin/env bash
# CrudeOS - canonical Alpine-based XFCE live ISO builder
# GUI included: XFCE + Docklike + Whisker + Picom + dark Adwaita theme
#
# Host requirements:
#   Docker or Podman
#
# Build:
#   chmod +x build_crude_os.sh
#   ./build_crude_os.sh
#
# Optional:
#   CRUDEOS_VERSION=1.0.0 ALPINE_VERSION=3.24.1 ./build_crude_os.sh

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

die() {
    echo "ERROR: $*" >&2
    exit 1
}

if command -v docker >/dev/null 2>&1; then
    RUNTIME=docker
elif command -v podman >/dev/null 2>&1; then
    RUNTIME=podman
else
    die "Docker or Podman is required."
fi

echo "=============================================="
echo "            CrudeOS Live ISO Builder"
echo "=============================================="
echo "CrudeOS version : $CRUDEOS_VERSION"
echo "Codename        : $CRUDEOS_CODENAME"
echo "Alpine base     : $ALPINE_VERSION"
echo "Architecture    : $ARCH"
echo "Container       : $CONTAINER_IMAGE"
echo "Runtime         : $RUNTIME"
echo "=============================================="

cat > "$WORK/mkimg.crudeos.sh" <<'PROFILE'
#!/bin/sh

profile_crudeos() {
    profile_standard

    title="CrudeOS"
    desc="CrudeOS - lightweight, polished XFCE desktop"
    kernel_flavors="lts"

    apks="$apks
        linux-lts
        linux-firmware

        # Core desktop
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
        adw-gtk3
        adwaita-xfce-icon-theme
        picom

        # Hardware / session
        dbus
        dbus-x11
        elogind
        polkit-elogind
        networkmanager
        network-manager-applet
        mesa-dri-gallium
        mesa-egl
        mesa-gl
        libinput
        xf86-input-libinput

        # Common drivers
        xf86-video-amdgpu
        xf86-video-intel
        xf86-video-nouveau

        # Audio
        pipewire
        pipewire-pulse
        wireplumber
        pavucontrol
        alsa-utils

        # Desktop utilities
        xarchiver
        mousepad
        ristretto
        htop
        git
        curl

        # Browser
        firefox-esr
    "

    apkovl="genapkovl-crudeos.sh"

    # Keep the compositor deliberately light: the goal is good frame pacing,
    # not expensive blur/shadow effects.
    kernel_cmdline="$kernel_cmdline quiet loglevel=3"
}

profile_crudeos
PROFILE

cat > "$WORK/genapkovl-crudeos.sh" <<'OVERLAY'
#!/bin/sh
set -eu

tmp="$1"

mkdir -p \
    "$tmp/etc/apk" \
    "$tmp/etc/xdg/autostart" \
    "$tmp/etc/xdg/picom" \
    "$tmp/etc/xdg/xfce4/xfconf/xfce-perchannel-xml" \
    "$tmp/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml" \
    "$tmp/etc/skel/.config/gtk-3.0" \
    "$tmp/etc/skel/.config/picom"

# The packages are installed in the image. /etc/apk/world makes the desktop
# persistent/visible to Alpine's package system in the generated live image.
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
networkmanager
network-manager-applet
mesa-dri-gallium
mesa-egl
mesa-gl
libinput
xf86-input-libinput
xf86-video-amdgpu
xf86-video-intel
xf86-video-nouveau
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

cat > "$tmp/etc/os-release" <<EOF
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

cat > "$tmp/etc/hostname" <<'HOST'
crudeos
HOST

cat > "$tmp/etc/motd" <<'MOTD'
   ____                 _      ____   ____
  / ___|_ __ _   _  __| | ___/ ___| / ___|
 | |   | '__| | | |/ _` |/ _ \___ \| |
 | |___| |  | |_| | (_| |  __/___) | |___
  \____|_|   \__,_|\__,_|\___|____/ \____|

             Welcome to CrudeOS
       Lightweight. Fast. Yours.
MOTD

cat > "$tmp/etc/xdg/picom/picom.conf" <<'PICOM'
backend = "glx";
vsync = true;
use-damage = true;

# Keep frame pacing smooth without expensive blur/shadow passes.
shadow = false;
blur-background = false;
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-delta = 8;

inactive-opacity = 0.94;
active-opacity = 1.0;
frame-opacity = 0.96;

wintypes:
{
    tooltip = { fade = true; shadow = false; };
    dock = { shadow = false; };
    popup_menu = { fade = true; };
    dropdown_menu = { fade = true; };
};
PICOM

cat > "$tmp/etc/xdg/autostart/crudeos-picom.desktop" <<'AUTOSTART'
[Desktop Entry]
Type=Application
Name=CrudeOS Compositor
Comment=Lightweight synchronized compositor
Exec=picom --config /etc/xdg/picom/picom.conf
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
NoDisplay=true
AUTOSTART

cat > "$tmp/etc/skel/.config/gtk-3.0/settings.ini" <<'GTK'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=DejaVu Sans 10
gtk-application-prefer-dark-theme=true
gtk-enable-animations=true
gtk-decoration-layout=close,minimize,maximize:
GTK

cat > "$tmp/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" <<'XFWM'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
    <property name="vblank_mode" type="string" value="glx"/>
    <property name="title_alignment" type="string" value="center"/>
    <property name="button_layout" type="string" value="O|HMC"/>
    <property name="frame_opacity" type="int" value="100"/>
    <property name="inactive_opacity" type="int" value="94"/>
    <property name="inactive_text_opacity" type="int" value="100"/>
  </property>
</channel>
XFWM

# Start the services needed for a usable graphical live system.
rc_add dbus default
rc_add elogind default
rc_add networkmanager default

# LightDM starts the graphical login when present.
rc_add lightdm default
OVERLAY

chmod +x "$WORK/mkimg.crudeos.sh" "$WORK/genapkovl-crudeos.sh"

"$RUNTIME" pull "$CONTAINER_IMAGE"

# Alpine's documented custom-image workflow uses mkimage.sh from aports.
"$RUNTIME" run --rm --privileged \
    -e APORTS_TAG="$ALPINE_BRANCH" \
    -e CRUDEOS_VERSION="$CRUDEOS_VERSION" \
    -e CRUDEOS_CODENAME="$CRUDEOS_CODENAME" \
    -e CRUDEOS_ARCH="$ARCH" \
    -v "$WORK:/work" \
    "$CONTAINER_IMAGE" /bin/sh -c '
set -eu
apk add --no-cache alpine-sdk alpine-conf abuild syslinux xorriso squashfs-tools grub mtools git

mkdir -p /work/aports /work/out /work/root
if [ ! -d /work/aports/.git ]; then
    git clone --depth=1 --branch "$APORTS_TAG" \
        https://gitlab.alpinelinux.org/alpine/aports.git /work/aports
fi

# Build-image tools need an abuild key available.
mkdir -p /root/.abuild
if ! find /etc/apk/keys -maxdepth 1 -type f -name "*.rsa.pub" | grep -q .; then
    abuild-keygen -ain
fi

cp /work/mkimg.crudeos.sh /work/aports/scripts/mkimg.crudeos.sh
cp /work/genapkovl-crudeos.sh /work/aports/scripts/genapkovl-crudeos.sh
chmod +x /work/aports/scripts/mkimg.crudeos.sh
chmod +x /work/aports/scripts/genapkovl-crudeos.sh

cd /work/aports
export PROFILENAME=crudeos

sh ./scripts/mkimage.sh \
    --tag "$APORTS_TAG" \
    --outdir /work/out \
    --workdir /work/work \
    --arch "$CRUDEOS_ARCH" \
    --profile crudeos \
    --repository "https://dl-cdn.alpinelinux.org/alpine/$APORTS_TAG/main" \
    --repository "https://dl-cdn.alpinelinux.org/alpine/$APORTS_TAG/community"

echo "=== generated images ==="
find /work/out -maxdepth 1 -type f -printf "%f\n" | sort
'

ISO="$(find "$WORK/out" -maxdepth 1 -type f -iname '*.iso' | head -n 1 || true)"
[ -n "$ISO" ] || die "Build finished, but no ISO file was generated."

FINAL="$OUT/crudeos-${CRUDEOS_VERSION}-${ARCH}.iso"
cp -f "$ISO" "$FINAL"

echo
echo "=============================================="
echo "CrudeOS build complete!"
echo "ISO: $FINAL"
echo
echo "SHA256:"
sha256sum "$FINAL"
echo "=============================================="
