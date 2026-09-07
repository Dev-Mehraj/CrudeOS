#!/bin/bash
# Crude OS Bootable ISO Builder
# Based on Alpine Linux with XFCE Desktop
# Fully rebranded as "Crude OS"

set -e

# Configuration
ISO_NAME="crude-os-xfce-x86_64.iso"
ISO_LABEL="CRUDE_OS"
WORK_DIR="/workspace/crude-os/work"
OUTPUT_DIR="/workspace/crude-os/output"
CONFIG_DIR="/workspace/crude-os/config"
OVERLAY_DIR="/workspace/crude-os/rootfs-overlay"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function
cleanup() {
    if [ -d "$WORK_DIR" ]; then
        log_warn "Cleaning up work directory..."
        rm -rf "$WORK_DIR"
    fi
}

# Trap errors
trap cleanup EXIT

# Create directories
log_info "Creating directory structure..."
mkdir -p "$WORK_DIR"/{rootfs,iso_root/{boot/grub,isolinux,EFI/BOOT}}
mkdir -p "$OUTPUT_DIR"

# Download Alpine Linux base (minirootfs)
log_info "Downloading Alpine Linux base..."
ALPINE_VERSION="3.19"
ALPINE_PATCH="0"
ALPINE_ARCH="x86_64"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/${ALPINE_ARCH}/alpine-minirootfs-${ALPINE_VERSION}.${ALPINE_PATCH}-${ALPINE_ARCH}.tar.gz"

if [ ! -f "$WORK_DIR/alpine-base.tar.gz" ]; then
    wget -O "$WORK_DIR/alpine-base.tar.gz" "$ALPINE_URL"
fi

# Extract Alpine base
log_info "Extracting Alpine base..."
tar -xzf "$WORK_DIR/alpine-base.tar.gz" -C "$WORK_DIR/rootfs"

# Install additional packages for XFCE desktop
log_info "Setting up package repositories..."
cat > "$WORK_DIR/rootfs/etc/apk/repositories" << EOF
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community
EOF

# Copy DNS configuration for chroot
cp /etc/resolv.conf "$WORK_DIR/rootfs/etc/resolv.conf"

# Update package list (retry if needed)
log_info "Updating package lists..."
for i in 1 2 3; do
    if chroot "$WORK_DIR/rootfs" apk update; then
        break
    fi
    log_warn "Retry $i/3 for apk update..."
    sleep 2
done

# Install XFCE and related packages in stages to handle missing packages gracefully
log_info "Installing core XFCE desktop environment..."
chroot "$WORK_DIR/rootfs" apk add --no-cache \
    xfce4 \
    lightdm \
    lightdm-gtk-greeter \
    xorg-server \
    dbus-openrc \
    eudev \
    || log_warn "Core XFCE installation had issues"

log_info "Installing additional applications..."
chroot "$WORK_DIR/rootfs" apk add --no-cache \
    firefox \
    gnumeric \
    abiword \
    ristretto \
    parole \
    mousepad \
    xterm \
    htop \
    vim \
    curl \
    wget \
    ca-certificates \
    || log_warn "Some applications failed to install"

log_info "Installing system utilities..."
chroot "$WORK_DIR/rootfs" apk add --no-cache \
    networkmanager \
    networkmanager-openrc \
    alsa-utils \
    pulseaudio-utils \
    pavucontrol \
    gvfs \
    tumbler \
    thunar-volman \
    || log_warn "Some utilities failed to install"

log_info "Installing kernel and bootloader..."
chroot "$WORK_DIR/rootfs" apk add --no-cache \
    linux-lts \
    grub \
    || log_warn "Kernel/bootloader installation had issues"

# Try installing optional packages separately
log_info "Installing optional packages..."
chroot "$WORK_DIR/rootfs" apk add --no-cache xfce4-goodies 2>/dev/null || log_warn "xfce4-goodies not available"
chroot "$WORK_DIR/rootfs" apk add --no-cache xorg-xinit 2>/dev/null || log_warn "xorg-xinit not available"
chroot "$WORK_DIR/rootfs" apk add --no-cache gnome-calculator 2>/dev/null || log_warn "gnome-calculator not available"
chroot "$WORK_DIR/rootfs" apk add --no-cache gnome-disk-utility 2>/dev/null || log_warn "gnome-disk-utility not available"
chroot "$WORK_DIR/rootfs" apk add --no-cache neofetch 2>/dev/null || log_warn "neofetch not available"
chroot "$WORK_DIR/rootfs" apk add --no-cache git 2>/dev/null || log_warn "git not available"
chroot "$WORK_DIR/rootfs" apk add --no-cache openntpd-openrc 2>/dev/null || log_warn "openntpd-openrc not available"
chroot "$WORK_DIR/rootfs" apk add --no-cache chromium 2>/dev/null || log_warn "chromium not available"

# Configure autostart for LightDM
log_info "Configuring display manager..."
mkdir -p "$WORK_DIR/rootfs/etc/skel"
echo "exec startxfce4" > "$WORK_DIR/rootfs/etc/skel/.xinitrc"
chmod +x "$WORK_DIR/rootfs/etc/skel/.xinitrc"

# Enable services
chroot "$WORK_DIR/rootfs" rc-update add dbus || true
chroot "$WORK_DIR/rootfs" rc-update add networkmanager || true
chroot "$WORK_DIR/rootfs" rc-update add lightdm || true

# Apply Crude OS branding
log_info "Applying Crude OS branding..."

# Create branding files
mkdir -p "$WORK_DIR/rootfs/usr/share/crude-os"

# Welcome message
cat > "$WORK_DIR/rootfs/etc/motd" << 'EOF'
  ____                 _     _ _       
 / ___|___  _   _ _ __(_)___| | |_ _ _ 
| |   / _ \| | | | '__| / __| | __| '_|
| |__| (_) | |_| | |  | \__ \ | |_| |  
 \____\___/ \__,_|_|  |_|___/_|\__|_|  
                                       
Welcome to Crude OS!
Based on Alpine Linux with XFCE Desktop
EOF

# Set hostname
echo "crude-os" > "$WORK_DIR/rootfs/etc/hostname"

# Create crude-os-release file
cat > "$WORK_DIR/rootfs/etc/crude-os-release" << 'EOF'
NAME="Crude OS"
VERSION="1.0"
ID=crude-os
ID_LIKE=alpine
VERSION_ID="1.0"
PRETTY_NAME="Crude OS 1.0 (XFCE)"
ANSI_COLOR="1;34"
HOME_URL="https://crude-os.example.com"
SUPPORT_URL="https://github.com/crude-os"
BUG_REPORT_URL="https://github.com/crude-os/issues"
EOF

# Copy overlay files
if [ -d "$OVERLAY_DIR" ]; then
    log_info "Applying rootfs overlay..."
    cp -r "$OVERLAY_DIR"/* "$WORK_DIR/rootfs/" 2>/dev/null || true
fi

# Create init script for live system
log_info "Creating live boot init script..."
cat > "$WORK_DIR/rootfs/live-init" << 'SCRIPT'
#!/bin/sh
# Live boot initialization for Crude OS

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Mount necessary filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

# Create necessary directories
mkdir -p /run/live /rootfs

# Find the boot device
for dev in /dev/sd* /dev/mmcblk* /dev/nvme* /dev/loop*; do
    if mount -t iso9660 -o ro "$dev" /run/live 2>/dev/null; then
        BOOT_DEV="$dev"
        break
    fi
done

if [ -z "$BOOT_DEV" ]; then
    echo "Failed to find boot device!"
    exec /bin/sh
fi

# Mount squashfs if it exists
if [ -f /run/live/livefs.squashfs ]; then
    mount -t squashfs -o loop /run/live/livefs.squashfs /rootfs
    mount --bind /rootfs /mnt
elif [ -d /run/live/rootfs ]; then
    mount --bind /run/live/rootfs /mnt
else
    echo "No root filesystem found!"
    exec /bin/sh
fi

# Continue normal boot
exec switch_root /mnt /sbin/init
SCRIPT

chmod +x "$WORK_DIR/rootfs/live-init"

# Compress rootfs to squashfs for live mode (optional, keeps ISO smaller)
log_info "Creating SquashFS image..."
mksquashfs "$WORK_DIR/rootfs" "$WORK_DIR/iso_root/livefs.squashfs" -comp xz -b 256k -Xdict-size 256k

# Copy kernel and initramfs from rootfs
log_info "Copying kernel and initramfs..."
cp "$WORK_DIR/rootfs/boot/vmlinuz-lts" "$WORK_DIR/iso_root/boot/vmlinuz"
cp "$WORK_DIR/rootfs/boot/initramfs-lts" "$WORK_DIR/iso_root/boot/initramfs.img"

# Create GRUB configuration for UEFI and BIOS
log_info "Creating GRUB configuration..."
cat > "$WORK_DIR/iso_root/boot/grub/grub.cfg" << 'GRUBCFG'
set timeout=10
set default=0

menuentry "Crude OS (Normal Mode)" {
    linux /boot/vmlinuz modules=loop,squashfs subdirs=live apkg_dev=auto quiet splash
    initrd /boot/initramfs.img
}

menuentry "Crude OS (Safe Mode)" {
    linux /boot/vmlinuz modules=loop,squashfs subdirs=live apkg_dev=auto nomodeset quiet
    initrd /boot/initramfs.img
}

menuentry "Crude OS (Text Mode)" {
    linux /boot/vmlinuz modules=loop,squashfs subdirs=live apkg_dev=auto textmode quiet
    initrd /boot/initramfs.img
}

menuentry "System Information" {
    linux /boot/vmlinuz modules=loop,squashfs subdirs=live apkg_dev=auto debug quiet
    initrd /boot/initramfs.img
}
GRUBCFG

# Create Syslinux/Isolinux configuration for BIOS boot
log_info "Creating Syslinux configuration..."
cat > "$WORK_DIR/iso_root/isolinux/isolinux.cfg" << 'ISOCFG'
DEFAULT crude
LABEL crude
  MENU LABEL ^Boot Crude OS (Normal)
  KERNEL /boot/vmlinuz
  INITRD /boot/initramfs.img
  APPEND modules=loop,squashfs subdirs=live apkg_dev=auto quiet splash

LABEL safe
  MENU LABEL ^Boot Crude OS (Safe Mode)
  KERNEL /boot/vmlinuz
  INITRD /boot/initramfs.img
  APPEND modules=loop,squashfs subdirs=live apkg_dev=auto nomodeset quiet

LABEL text
  MENU LABEL ^Boot Crude OS (Text Mode)
  KERNEL /boot/vmlinuz
  INITRD /boot/initramfs.img
  APPEND modules=loop,squashfs subdirs=live apkg_dev=auto textmode quiet

LABEL debug
  MENU LABEL ^System Information
  KERNEL /boot/vmlinuz
  INITRD /boot/initramfs.img
  APPEND modules=loop,squashfs subdirs=live apkg_dev=auto debug quiet

LABEL memtest
  MENU LABEL ^Memory Test (memtest86+)
  KERNEL /boot/memtest

UI menu.c32
PROMPT 1
TIMEOUT 100
ISOCFG

# Copy isolinux binaries
cp /usr/lib/ISOLINUX/isolinux.bin "$WORK_DIR/iso_root/isolinux/"
cp /usr/lib/syslinux/modules/bios/menu.c32 "$WORK_DIR/iso_root/isolinux/"

# Create EFI boot image
log_info "Creating EFI boot image..."
dd if=/dev/zero of="$WORK_DIR/iso_root/EFI/BOOT/efiboot.img" bs=1M count=20
mkfs.vfat -n "EFIBOOT" "$WORK_DIR/iso_root/EFI/BOOT/efiboot.img"

# Copy GRUB EFI binary
if [ -f /usr/lib/grub/x86_64-efi/grub.efi ]; then
    mkdir -p "$WORK_DIR/efi_tmp"
    mount -o loop "$WORK_DIR/iso_root/EFI/BOOT/efiboot.img" "$WORK_DIR/efi_tmp"
    mkdir -p "$WORK_DIR/efi_tmp/EFI/BOOT"
    cp /usr/lib/grub/x86_64-efi/grub.efi "$WORK_DIR/efi_tmp/EFI/BOOT/BOOTx64.EFI"
    
    # Create EFI grub.cfg
    cat > "$WORK_DIR/efi_tmp/EFI/BOOT/grub.cfg" << 'EFICFG'
set timeout=10
search --no-floppy --label CRUDE_OS --set root
configfile /boot/grub/grub.cfg
EFICFG
    
    umount "$WORK_DIR/efi_tmp"
    rmdir "$WORK_DIR/efi_tmp"
fi

# Create the bootable ISO using xorriso
log_info "Creating bootable ISO image..."
xorriso -as mkisofs \
    -V "$ISO_LABEL" \
    -J \
    -R \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e EFI/BOOT/efiboot.img \
    -no-emul-boot \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -o "$OUTPUT_DIR/$ISO_NAME" \
    "$WORK_DIR/iso_root"

# Verify ISO
log_info "Verifying ISO..."
if [ -f "$OUTPUT_DIR/$ISO_NAME" ]; then
    ISO_SIZE=$(du -h "$OUTPUT_DIR/$ISO_NAME" | cut -f1)
    log_info "Successfully created: $OUTPUT_DIR/$ISO_NAME"
    log_info "ISO Size: $ISO_SIZE"
    log_info "ISO Label: $ISO_LABEL"
    
    # Show ISO info
    isoinfo -d -i "$OUTPUT_DIR/$ISO_NAME" | grep -E "(Volume id|Logical block size|Volume size)"
else
    log_error "Failed to create ISO!"
    exit 1
fi

log_info "Build complete! You can test the ISO with:"
log_info "  qemu-system-x86_64 -cdrom $OUTPUT_DIR/$ISO_NAME -boot d -m 2048"
log_info "Or write to USB with:"
log_info "  dd if=$OUTPUT_DIR/$ISO_NAME of=/dev/sdX bs=4M status=progress"
