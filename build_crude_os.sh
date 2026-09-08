#!/usr/bin/env bash
# CrudeOS ISO Builder
#
# Builds a bootable CrudeOS XFCE live ISO using Alpine's supported mkimage
# workflow inside an Alpine builder container.
#
# Host requirements:
#   - Docker OR Podman
#
# Usage:
#   ./build_crude_os.sh
#   CRUDEOS_VERSION=1.0.0 ./build_crude_os.sh
#
# The resulting ISO is written to:
#   ./dist/crudeos-x86_64-<version>.iso

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$ROOT_DIR/dist"
WORK_DIR="$ROOT_DIR/.crudeos-build"

ALPINE_VERSION="${ALPINE_VERSION:-3.24.1}"
ALPINE_BRANCH="${ALPINE_BRANCH:-v3.24}"
CRUDEOS_VERSION="${CRUDEOS_VERSION:-1.0.0}"
CRUDEOS_CODENAME="${CRUDEOS_CODENAME:-Forge}"
CRUDEOS_ARCH="${CRUDEOS_ARCH:-x86_64}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-alpine:${ALPINE_VERSION}}"

mkdir -p "$DIST_DIR" "$WORK_DIR"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

find_runtime() {
    if command -v docker >/dev/null 2>&1; then
        printf '%s\n' docker
    elif command -v podman >/dev/null 2>&1; then
        printf '%s\n' podman
    else
        die "Docker or Podman is required."
    fi
}

RUNTIME="$(find_runtime)"

echo "=============================================="
echo "             CrudeOS ISO Builder"
echo "=============================================="
echo "Alpine base : $ALPINE_VERSION"
echo "Architecture: $CRUDEOS_ARCH"
echo "CrudeOS     : $CRUDEOS_VERSION ($CRUDEOS_CODENAME)"
echo "Container   : $CONTAINER_IMAGE"
echo "Runtime     : $RUNTIME"
echo

cat > "$WORK_DIR/profile" <<'PROFILE'
#!/bin/sh

profile_crudeos() {
    profile_standard

    title="CrudeOS"
    desc="CrudeOS ${CRUDEOS_VERSION} - lightweight XFCE desktop"

    # Keep Alpine's tested kernel/initramfs generation.
    kernel_flavors="lts"

    # Desktop, networking, firmware and useful desktop applications.
    apks="$apks
        alpine-base
        linux-lts
        linux-firmware
        xfce4
        xfce4-goodies
        lightdm
        lightdm-gtk-greeter
        networkmanager
        network-manager-applet
        dbus
        dbus-x11
        elogind
        polkit-elogind
        xf86-input-libinput
        xf86-video-amdgpu
        xf86-video-intel
        xf86-video-nouveau
        mesa-dri-gallium
        mesa-vulkan-intel
        mesa-vulkan-radeon
        firefox-esr
        thunar-volman
        tumbler
        ristretto
        mousepad
        parole
        xarchiver
        pavucontrol
        alsa-utils
        pipewire
        pipewire-pulse
        wireplumber
        gnome-keyring
        htop
        git
        vim
    "

    # Generate the CrudeOS configuration overlay used by the live system.
    apkovl="/work/genapkovl-crudeos.sh"
}
PROFILE
chmod +x "$WORK_DIR/profile"

cat > "$WORK_DIR/genapkovl-crudeos.sh" <<'OVERLAY'
#!/bin/sh
set -eu

tmp="$1"

mkdir -p "$tmp/etc/apk"
mkdir -p "$tmp/etc/lightdm"
mkdir -p "$tmp/etc/profile.d"

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

cat > "$tmp/etc/hostname" <<'EOF'
crudeos
EOF

cat > "$tmp/etc/motd" <<'EOF'
   ____                 _      ____   ____
  / ___|_ __ _   _  __| | ___/ ___| / ___|
 | |   | '__| | | |/ _` |/ _ \___ \| |
 | |___| |  | |_| | (_| |  __/___) | |___
  \____|_|   \__,_|\__,_|\___|____/ \____|

Welcome to CrudeOS.
A lightweight desktop system built on the Alpine Linux base.
EOF

cat > "$tmp/etc/lightdm/lightdm.conf" <<'EOF'
[Seat:*]
user-session=xfce
greeter-session=lightdm-gtk-greeter
EOF

cat > "$tmp/etc/profile.d/crudeos.sh" <<'EOF'
export CRUDEOS_NAME="CrudeOS"
export CRUDEOS_VERSION="__CRUDEOS_VERSION__"
EOF
sed -i "s/__CRUDEOS_VERSION__/${CRUDEOS_VERSION}/g" "$tmp/etc/profile.d/crudeos.sh"

# Tell OpenRC to start the desktop stack.
rc_add dbus default
rc_add networkmanager default
rc_add lightdm default
OVERLAY
chmod +x "$WORK_DIR/genapkovl-crudeos.sh"

# Generate a Docker/Podman build script.
cat > "$WORK_DIR/build-inside.sh" <<'INNER'
#!/bin/sh
set -eu

apk update
apk add --no-cache \
    alpine-sdk \
    bash \
    git \
    mtools \
    grub \
    syslinux \
    xorriso \
    squashfs-tools

mkdir -p /work/aports /work/out
cd /work

if [ ! -d /work/aports/.git ]; then
    git clone --depth=1 --branch "$APORTS_BRANCH" \
        https://gitlab.alpinelinux.org/alpine/aports.git /work/aports
fi

# Ensure the builder has an APK signing key for image creation.
if ! find /etc/apk/keys -maxdepth 1 -type f -name '*.rsa.pub' | grep -q .; then
    abuild-keygen -a -n
fi

cp /work/profile /work/aports/scripts/mkimg.crudeos.sh
cp /work/genapkovl-crudeos.sh /work/genapkovl-crudeos.sh
chmod +x /work/aports/scripts/mkimg.crudeos.sh
chmod +x /work/genapkovl-crudeos.sh

export PROFILENAME=crudeos

# Pass the version into the profile/overlay generator.
export CRUDEOS_VERSION
export CRUDEOS_CODENAME

# Build with Alpine's official image generator.
sh /work/aports/scripts/mkimage.sh \
    --tag "$APORTS_TAG" \
    --outdir /work/out \
    --workdir /work/work \
    --arch "$CRUDEOS_ARCH" \
    --profile "$PROFILENAME" \
    --repository "https://dl-cdn.alpinelinux.org/alpine/${APORTS_TAG}/main" \
    --repository "https://dl-cdn.alpinelinux.org/alpine/${APORTS_TAG}/community"

echo
echo "Generated images:"
find /work/out -maxdepth 1 -type f -printf '%f\n' | sort
INNER
chmod +x "$WORK_DIR/build-inside.sh"

# Run with enough privileges for mkimage's filesystem/image operations.
"$RUNTIME" pull "$CONTAINER_IMAGE"

"$RUNTIME" run --rm --privileged \
    -e APORTS_BRANCH="$ALPINE_BRANCH" \
    -e APORTS_TAG="$ALPINE_BRANCH" \
    -e CRUDEOS_VERSION="$CRUDEOS_VERSION" \
    -e CRUDEOS_CODENAME="$CRUDEOS_CODENAME" \
    -e CRUDEOS_ARCH="$CRUDEOS_ARCH" \
    -v "$WORK_DIR:/work" \
    "$CONTAINER_IMAGE" \
    /work/build-inside.sh

# Prefer the generated ISO and give it a stable project name.
ISO="$(find "$DIST_DIR" "$WORK_DIR/out" -maxdepth 1 -type f \
    \( -name '*.iso' -o -name '*.iso.xz' \) 2>/dev/null | head -n1 || true)"

if [ -z "$ISO" ]; then
    # mkimage may place the ISO directly in /work/out under a profile-derived name.
    ISO="$(find "$WORK_DIR/out" -maxdepth 1 -type f -name '*.iso' | head -n1 || true)"
fi

[ -n "$ISO" ] || die "mkimage completed, but no ISO was found."

FINAL="$DIST_DIR/crudeos-${CRUDEOS_VERSION}-${CRUDEOS_ARCH}.iso"
cp -f "$ISO" "$FINAL"

echo
echo "=============================================="
echo "Build complete."
echo "ISO: $FINAL"
echo "SHA256:"
sha256sum "$FINAL"
echo "=============================================="
