#!/bin/bash
# Crude OS Build Script
# Base: Alpine Linux
# Desktop: XFCE4
# Branding: Crude OS
# Host System: Debian/Ubuntu compatible

set -e

# Configuration
ISO_LABEL="CRUDE_OS"
ISO_NAME="crude-os-xfce.iso"
BUILD_DIR="/workspace/crude_os_build"
CHROOT_DIR="$BUILD_DIR/chroot"
ISO_ROOT="$BUILD_DIR/iso_root"
ALPINE_VERSION="3.24.0"
ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"

echo "=========================================="
echo "   Starting Crude OS Build Process"
echo "=========================================="

# Cleanup previous builds
if [ -d "$BUILD_DIR" ]; then
    echo "Cleaning up previous build directory..."
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
mkdir -p "$CHROOT_DIR"
mkdir -p "$ISO_ROOT"

# Install required host tools (Debian/Ubuntu)
echo "Installing required host tools on Debian host..."
apt-get update -qq
apt-get install -y -qq wget squashfs-tools genisoimage isolinux xz-utils

# Download Alpine Miniroot
echo "Downloading Alpine Linux minirootfs..."
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH="x86_64"
elif [ "$ARCH" = "aarch64" ]; then
    ARCH="aarch64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

MINIROOT_URL="$ALPINE_MIRROR/v${ALPINE_VERSION%.*}/releases/$ARCH/alpine-minirootfs-$ALPINE_VERSION-$ARCH.tar.gz"
echo "Downloading from: $MINIROOT_URL"
wget --show-progress "$MINIROOT_URL" -O "$BUILD_DIR/alpine-miniroot.tar.gz" || {
    echo "Failed to download from primary URL, trying alternative..."
    # Try without the patch version in directory path
    ALT_URL="$ALPINE_MIRROR/v${ALPINE_VERSION%.*}/releases/$ARCH/alpine-minirootfs-${ALPINE_VERSION%.*}.$(echo $ALPINE_VERSION | cut -d. -f3)-$ARCH.tar.gz"
    wget --show-progress "$ALT_URL" -O "$BUILD_DIR/alpine-miniroot.tar.gz" || exit 1
}

# Extract to chroot
echo "Extracting Alpine base system..."
tar -xzf "$BUILD_DIR/alpine-miniroot.tar.gz" -C "$CHROOT_DIR"

# Setup repositories in chroot
echo "Configuring package repositories..."
cp /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf"
echo "$ALPINE_MIRROR/v$ALPINE_VERSION/main" > "$CHROOT_DIR/etc/apk/repositories"
echo "$ALPINE_MIRROR/v$ALPINE_VERSION/community" >> "$CHROOT_DIR/etc/apk/repositories"

# Mount proc/sys/dev for chroot
mount -t proc /proc "$CHROOT_DIR/proc"
mount -t sysfs /sys "$CHROOT_DIR/sys"
mount --rbind /dev "$CHROOT_DIR/dev"
mount --rbind /run "$CHROOT_DIR/run"

# Enter chroot and install packages
echo "Entering chroot to install Crude OS components..."
chroot "$CHROOT_DIR" /bin/sh << 'EOF'
# Update package list
apk update

# Install Core System Components
apk add --no-cache linux-lts linux-firmware lvm2 mdadm e2fsprogs dosfstools xfsprogs btrfs-progs

# Install Network Tools
apk add --no-cache networkmanager network-manager-applet dhclient openntp inetutils traceroute

# Install X Server and Video Drivers
apk add --no-cache xorg-server xorg-xinit mesa-dri-gallium xf86-video-intel xf86-video-amdgpu xf86-video-ati xf86-video-nouveau xf86-video-vesa xf86-input-libinput

# Install XFCE4 Desktop Environment
apk add --no-cache xfce4 xfce4-goodies

# Install Display Manager (LightDM) and Greeter
apk add --no-cache lightdm lightdm-gtk-greeter

# Install Essential Applications
apk add --no-cache \
    firefox-esr \
    thunar-volman \
    tumbler \
    ristretto \
    mousepad \
    parole \
    xarchiver \
    gnumeric \
    abiword \
    pavucontrol \
    alsa-utils \
    pulseaudio-utils \
    gnome-keyring \
    polkit-gnome \
    dbus-x11 \
    htop \
    neofetch \
    git \
    vim

# --- CRUDE OS BRANDING ---

# Set Hostname
echo "crude-os" > /etc/hostname

# Create Crude OS Welcome Message (MOTD)
cat > /etc/motd << 'MOTD'
  ____       _ _     _            _ 
 / ___|___  | (_) __| | ___ _ __ | |_ 
| |   / _ \ | | |/ _` |/ _ \ '_ \| __|
| |__| (_) || | | (_| |  __/ | | | |_ 
 \____\___(_)_|_|\__,_|\___|_| |_|\__|
                                      
Welcome to Crude OS!
Based on Alpine Linux with XFCE4.
Ready for use.
MOTD

# Set default runlevel to graphical
rc-update add lightdm default
rc-update add networkmanager default
rc-update add dbus default

# Configure LightDM to autostart XFCE
mkdir -p /etc/lightdm
cat > /etc/lightdm/lightdm.conf << 'LIGHTDM'
[SeatDefaults]
autologin-user=
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
LIGHTDM

# Clean up APK cache to reduce ISO size
apk cache clean

echo "Crude OS system configured inside chroot."
EOF

# Unmount virtual filesystems
echo "Unmounting chroot filesystems..."
umount -R "$CHROOT_DIR/run" 2>/dev/null || true
umount -R "$CHROOT_DIR/dev" 2>/dev/null || true
umount "$CHROOT_DIR/sys" 2>/dev/null || true
umount "$CHROOT_DIR/proc" 2>/dev/null || true

# Prepare ISO Root Structure
echo "Preparing ISO filesystem structure..."
mkdir -p "$ISO_ROOT/boot"
mkdir -p "$ISO_ROOT/isolinux"
mkdir -p "$ISO_ROOT/live"

# Copy Kernel and Initramfs from Chroot
echo "Copying kernel and initramfs..."
cp "$CHROOT_DIR/boot/vmlinuz-lts" "$ISO_ROOT/boot/vmlinuz"
cp "$CHROOT_DIR/boot/initramfs-lts" "$ISO_ROOT/boot/initramfs"

# Create SquashFS for the live system
echo "Creating SquashFS image of the root system..."
mksquashfs "$CHROOT_DIR" "$ISO_ROOT/live/crude_os.sfs" -noappend -comp xz -b 256k -Xdict-size 100%

# Create Isolinux configuration
echo "Creating boot loader configuration..."
cat > "$ISO_ROOT/isolinux/isolinux.cfg" << ISOCFG
DEFAULT crude
LABEL crude
  MENU LABEL Boot Crude OS (Default)
  KERNEL /boot/vmlinuz
  INITRD /boot/initramfs
  APPEND modules=ext4 root=live:/live/crude_os.sfs quiet
LABEL text
  MENU LABEL Boot Crude OS (Text Mode)
  KERNEL /boot/vmlinuz
  INITRD /boot/initramfs
  APPEND modules=ext4 root=live:/live/crude_os.sfs quiet nomodeset
ISOCFG

# Copy Isolinux binaries
echo "Copying isolinux bootloader files..."
if [ -f /usr/lib/ISOLINUX/isolinux.bin ]; then
    cp /usr/lib/ISOLINUX/isolinux.bin "$ISO_ROOT/isolinux/"
    cp /usr/lib/ISOLINUX/ldlinux.c32 "$ISO_ROOT/isolinux/"
elif [ -f /usr/share/syslinux/isolinux.bin ]; then
    cp /usr/share/syslinux/isolinux.bin "$ISO_ROOT/isolinux/"
    cp /usr/share/syslinux/ldlinux.c32 "$ISO_ROOT/isolinux/"
elif [ -f /usr/lib/syslinux/bios/isolinux.bin ]; then
    cp /usr/lib/syslinux/bios/isolinux.bin "$ISO_ROOT/isolinux/"
    cp /usr/lib/syslinux/bios/ldlinux.c32 "$ISO_ROOT/isolinux/"
else
    echo "Error: Isolinux binaries not found. Trying to install isolinux package..."
    apt-get install -y isolinux
    if [ -f /usr/lib/ISOLINUX/isolinux.bin ]; then
        cp /usr/lib/ISOLINUX/isolinux.bin "$ISO_ROOT/isolinux/"
        cp /usr/lib/ISOLINUX/ldlinux.c32 "$ISO_ROOT/isolinux/"
    elif [ -f /usr/share/syslinux/isolinux.bin ]; then
        cp /usr/share/syslinux/isolinux.bin "$ISO_ROOT/isolinux/"
        cp /usr/share/syslinux/ldlinux.c32 "$ISO_ROOT/isolinux/"
    else
        echo "Critical Error: Could not find isolinux binaries after installation."
        ls -la /usr/lib/ISOLINUX/ 2>/dev/null || true
        ls -la /usr/share/syslinux/ 2>/dev/null || true
        exit 1
    fi
fi

# Generate the ISO
echo "Generating Crude OS ISO image..."
genisoimage -o "$BUILD_DIR/$ISO_NAME" \
    -V "$ISO_LABEL" \
    -sysid "" \
    -A "Crude OS" \
    -input-charset utf-8 \
    -quiet \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    "$ISO_ROOT"

echo "=========================================="
echo "Build Complete!"
echo "ISO Location: $BUILD_DIR/$ISO_NAME"
echo "Size: $(du -h "$BUILD_DIR/$ISO_NAME" | cut -f1)"
echo "=========================================="
