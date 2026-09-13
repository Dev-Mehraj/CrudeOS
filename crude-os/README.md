# Crude OS

A fully bootable, install-ready Linux distribution based on Alpine Linux with XFCE desktop environment, completely rebranded as **Crude OS**.

## Features

- 🚀 **Bootable ISO** - Hybrid BIOS/UEFI boot support
- 🖥️ **XFCE Desktop** - Lightweight yet powerful GUI
- 📦 **Alpine Base** - Security-focused, minimal footprint
- 🎨 **Complete Rebranding** - All "Alpine" references replaced with "Crude OS"
- 🔧 **Install Ready** - Includes installer for permanent installation

## Directory Structure

```
crude-os/
├── config/
│   ├── boot/          # Bootloader configurations
│   └── branding/      # Branding assets (logos, wallpapers)
├── scripts/
│   └── build_crude_os.sh  # Main build script
├── output/            # Generated ISO files
├── work/              # Temporary build files (generated during build)
└── README.md
```

## Prerequisites

The following packages are required and have been pre-installed:

- `xorriso` - ISO creation tool
- `syslinux` / `isolinux` - BIOS bootloader
- `grub-pc-bin` / `grub-efi-amd64-bin` - UEFI bootloader
- `mtools` - DOS filesystem utilities
- `dosfstools` - FAT filesystem creation
- `squashfs-tools` - Compressed filesystem creation
- `wget` - File downloading
- `qemu-system-x86` - ISO testing

## Building the ISO

```bash
cd /workspace/crude-os
chmod +x scripts/build_crude_os.sh
sudo ./scripts/build_crude_os.sh
```

**Note:** Root privileges are required for building the ISO.

## Testing the ISO

After building, test the ISO with QEMU:

```bash
qemu-system-x86_64 -cdrom output/crude-os-1.0-x86_64.iso -m 2048 -boot d
```

## Installation to USB

To create a bootable USB drive:

```bash
# WARNING: This will erase all data on the target device!
sudo dd if=output/crude-os-1.0-x86_64.iso of=/dev/sdX bs=4M status=progress
sudo sync
```

Replace `/dev/sdX` with your actual USB device (e.g., `/dev/sdb`).

## Boot Options

The ISO provides the following boot options:

1. **Boot Crude OS (Live Session)** - Full graphical desktop environment
2. **Boot Crude OS (Text mode)** - Command-line only mode
3. **Memory Test** - Run memtest86+ for RAM diagnostics

## System Requirements

- **RAM:** 2GB minimum (4GB recommended)
- **Storage:** 8GB for installation (ISO is ~800MB-1.2GB)
- **CPU:** x86_64 compatible processor
- **Boot:** BIOS or UEFI firmware

## Customization

Edit `scripts/build_crude_os.sh` to customize:

- `DISTRO_NAME` - Distribution name
- `VERSION` - Version number
- `ALPINE_VERSION` - Base Alpine version
- Package selection in `build_rootfs()` function

## License

This project is provided as-is for educational and experimental purposes.

## Support

For issues and feature requests, please open an issue in the repository.

---

**Built with ❤️ using Alpine Linux as base**
