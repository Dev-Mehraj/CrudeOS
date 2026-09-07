#!/bin/bash
# Crude OS - Quick Build Helper
# This script checks dependencies and runs the build

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_SCRIPT="$SCRIPT_DIR/scripts/build_bootable_iso.sh"

echo "=========================================="
echo "  Crude OS - Build Environment Check"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "[ERROR] Please run as root (sudo ./quick-build.sh)"
    exit 1
fi

# Check required commands
REQUIRED_CMDS="xorriso syslinux mkfs.vfat mksquashfs wget tar cpio"
MISSING_CMDS=""

for cmd in $REQUIRED_CMDS; do
    if ! command -v $cmd &> /dev/null; then
        MISSING_CMDS="$MISSING_CMDS $cmd"
    fi
done

# Special check for isolinux binary (it's a file, not a command)
if [ ! -f /usr/lib/ISOLINUX/isolinux.bin ]; then
    MISSING_CMDS="$MISSING_CMDS isolinux-bin"
fi

if [ -n "$MISSING_CMDS" ]; then
    echo "[ERROR] Missing required commands:$MISSING_CMDS"
    echo ""
    echo "Install with:"
    echo "  apt-get update && apt-get install -y xorriso syslinux isolinux mtools dosfstools squashfs-tools wget"
    exit 1
fi

echo "[OK] All required commands found"

# Check disk space
AVAILABLE_SPACE=$(df -P "$SCRIPT_DIR" | awk 'NR==2 {print $4}')
MIN_SPACE=5242880  # 5GB in KB

if [ "$AVAILABLE_SPACE" -lt "$MIN_SPACE" ]; then
    echo "[WARN] Low disk space. Recommended: 5GB free"
    echo "       Available: $((AVAILABLE_SPACE / 1024)) MB"
fi

echo "[OK] Disk space check passed"

# Check for /dev/kvm (optional, for faster builds in some cases)
if [ ! -e /dev/kvm ]; then
    echo "[INFO] KVM not available (optional for build)"
fi

echo ""
echo "=========================================="
echo "  Starting Crude OS Build..."
echo "=========================================="
echo ""

# Run the build script
exec "$BUILD_SCRIPT"
