# 🖥️ CrudeOS

> **A lightweight, Alpine-based Linux desktop distribution with a custom XFCE experience.**

**CrudeOS** is a Linux distribution project built on top of **Alpine Linux**, customized with the **XFCE desktop environment**, a custom **CrudeOS Aqua** visual identity, live-boot support, and a graphical **Calamares installer**.

The project focuses on creating a lightweight, fast, customizable desktop Linux experience while keeping Alpine Linux as the underlying base.

> 🚧 **Status: Experimental / Active Development**

---

## ✨ Features

### 🖥️ CrudeOS Aqua Desktop

CrudeOS ships with a heavily customized XFCE environment designed around a modern, minimal, dark "Aqua" aesthetic.

* 🌊 Custom **CrudeOS Aqua** wallpaper
* 🪟 Custom XFWM4 window-manager theme
* 🎨 Dark GTK styling
* 🖼️ Papirus-Dark icon theme
* 🔤 Inter and Noto fonts
* 🚀 Floating application dock
* 🔎 Rofi application launcher
* 📋 Customized Whisker application menu
* 🖥️ Four-workspace configuration
* ✨ Picom/compositor support
* 🎛️ Customized XFCE panels
* 🔊 PipeWire + WirePlumber audio stack

---

## 🧱 Base System

CrudeOS uses **Alpine Linux** as its upstream base.

This provides CrudeOS with Alpine's lightweight package ecosystem and `apk` package manager while allowing the project to build a customized desktop environment on top.

```text
CrudeOS
   │
   ├── Alpine Linux base
   │
   ├── Linux LTS kernel
   │
   ├── XFCE Desktop
   │
   ├── Xorg
   │
   ├── LightDM
   │
   ├── NetworkManager
   │
   ├── PipeWire / WirePlumber
   │
   └── Calamares Installer
```

---

## 📦 Included Software

The build system installs and configures a collection of desktop applications and system utilities.

### Desktop

* XFCE4
* XFCE Session
* XFCE Panel
* XFWM4
* Thunar
* XFCE Terminal
* Mousepad
* XFCE Task Manager
* XFCE Screenshooter
* Whisker Menu
* Docklike

### Graphics

* Xorg Server
* Mesa
* `xf86-video-amdgpu`
* `xf86-video-intel`
* `xf86-video-nouveau`
* `xf86-video-vesa`
* `xf86-input-libinput`

### Applications

* Firefox ESR
* Xarchiver
* Ristretto
* Gnumeric
* Mousepad
* Thunar
* Pavucontrol

### System Tools

* htop
* Vim
* Git
* curl
* wget
* sudo
* ca-certificates

### Networking

* NetworkManager
* NetworkManager Applet
* DHCP/network utilities

### Audio

* PipeWire
* PipeWire Pulse
* WirePlumber
* ALSA utilities
* Pavucontrol

### Installation

* Calamares
* Calamares extensions
* Polkit
* Parted

---

## 🚀 Live Environment

CrudeOS is designed to be distributed as a **live bootable ISO**.

The root filesystem is compressed into a **SquashFS** image, allowing the system to run directly from installation media without immediately installing it to disk.

The live environment creates a default `crudeos` user and prepares the XFCE desktop automatically.

### Live-session components

* Custom user initialization
* Passwordless sudo for the live session
* NetworkManager
* LightDM
* XFCE
* Custom wallpaper and themes
* Custom application launcher
* CrudeOS session initialization

---

## 💿 Boot Support

The project contains boot configuration for both traditional BIOS and UEFI environments.

### BIOS

Uses:

* ISOLINUX
* Syslinux components
* BIOS boot configuration

### UEFI

Uses:

* GRUB
* EFI boot image
* `BOOTx64.EFI`

### Available boot modes

Depending on the build configuration, the boot menu provides options such as:

* **CrudeOS Normal Mode**
* **CrudeOS Safe Mode**
* **CrudeOS Text Mode**
* **System Information**
* **Memory Test**

---

## 🛠️ Building CrudeOS

The primary build system is implemented in:

```text
build_crude_os.sh
```

The builder automatically:

1. Checks for Docker or Podman
2. Creates a temporary build environment
3. Generates the package manifest
4. Creates the CrudeOS Alpine profile
5. Generates the filesystem overlay
6. Configures XFCE
7. Configures LightDM
8. Configures NetworkManager
9. Configures PipeWire
10. Applies CrudeOS branding
11. Generates the live filesystem
12. Builds the bootable ISO
13. Places the final image in `dist/`

### Requirements

A container runtime is required:

* Docker **or**
* Podman

### Build

```bash
chmod +x build_crude_os.sh
./build_crude_os.sh
```

The resulting ISO is placed in:

```text
dist/
```

---

## ⚙️ Build Configuration

The main builder exposes several environment variables that can be overridden without modifying the script.

### Default configuration

```bash
ALPINE_VERSION=3.24.1
ALPINE_BRANCH=v3.24
CRUDEOS_VERSION=1.0.0
CRUDEOS_CODENAME=Aqua
ARCH=x86_64
```

For example:

```bash
CRUDEOS_VERSION=1.1.0 \
CRUDEOS_CODENAME=Forge \
./build_crude_os.sh
```

---

## 🧪 Testing

The project is designed to be tested using QEMU.

Example:

```bash
qemu-system-x86_64 \
    -cdrom dist/crudeos-xfce.iso \
    -m 2048
```

For a more isolated test environment, virtualization settings can be adjusted according to the host system.

---

## 📁 Repository Structure

```text
CrudeOS/
├── build_crude_os.sh
├── build_crude_os_unprivileged.sh
├── rebrand_crudeos.sh
│
├── crude-os/
│   ├── README.md
│   │
│   ├── config/
│   │   ├── boot/
│   │   │   ├── grub.cfg
│   │   │   └── isolinux.cfg
│   │   │
│   │   └── branding/
│   │       └── os-release
│   │
│   ├── rootfs-overlay/
│   │   └── etc/
│   │       └── skel/
│   │           ├── Desktop/
│   │           └── setup-user.sh
│   │
│   ├── scripts/
│   │   ├── build_bootable_iso.sh
│   │   └── build_crude_os.sh
│   │
│   └── quick-build.sh
│
├── crude-os-calamares/
│   ├── crudeos/
│   │   ├── branding.desc
│   │   └── show.qml
│   │
│   ├── crudeos-users.conf
│   ├── crudeos-welcome.conf
│   ├── install-crudeos-installer.sh
│   └── settings.yml
│
└── crude_os_build/
    └── ...
```

Generated build artifacts and temporary root filesystems are also present in the repository/build workflow.

---

## 🎨 CrudeOS Aqua

The desktop configuration is one of the main parts of CrudeOS.

The project generates a custom visual environment containing:

* CrudeOS Aqua wallpaper
* Custom XFWM4 theme
* Dark GTK configuration
* Papirus-Dark icons
* Inter typography
* Floating dock
* Rofi "Spotlight"-style launcher
* Customized Whisker menu
* XFCE panel configuration
* NetworkManager applet
* Audio controls
* Power management
* Notifications
* Clock

The default dock includes applications such as:

```text
Firefox
Thunar
XFCE Terminal
Mousepad
XFCE Task Manager
XFCE Settings
```

---

## 🔎 Rofi Launcher

CrudeOS includes a custom Rofi configuration intended to provide a Spotlight-like application launcher.

The launcher can be invoked through:

```bash
crudeos-spotlight
```

It provides application search through Rofi's `drun` mode.

---

## 👤 Live User

The live environment creates a default user:

```text
Username: crudeos
```

The account is intended specifically for the live/demo environment.

The installer is designed to create a **separate user account for a permanent installation**.

The live user is also configured for passwordless `sudo` so that the live environment can perform administrative tasks.

---

## 💾 Installation

CrudeOS integrates **Calamares** as its graphical installer.

The repository contains dedicated Calamares configuration and branding:

```text
crude-os-calamares/
├── crudeos/
│   ├── branding.desc
│   └── show.qml
├── crudeos-users.conf
├── crudeos-welcome.conf
├── install-crudeos-installer.sh
└── settings.yml
```

This allows the installer experience to be customized specifically for CrudeOS rather than presenting a generic Alpine installation interface.

---

## 🔧 Alternative Build Path

CrudeOS also contains an unprivileged build script:

```text
build_crude_os_unprivileged.sh
```

This build path is intended for environments where normal mount/chroot operations are restricted, such as certain containers or CI environments.

It uses:

* Alpine minirootfs
* `qemu-user-static`
* SquashFS
* Syslinux/ISOLINUX
* `genisoimage`

The script also contains fallback behavior when the full Alpine setup cannot be executed.

---

## ⚡ Quick Build

Inside the `crude-os` directory there is also a helper:

```bash
sudo ./quick-build.sh
```

The helper checks for required tools such as:

```text
xorriso
syslinux
mkfs.vfat
mksquashfs
wget
tar
cpio
```

It also checks available disk space before starting the build.

---

## 🧩 Customization

CrudeOS is designed to be modified.

You can customize:

### Distribution metadata

```text
CRUDEOS_VERSION
CRUDEOS_CODENAME
ARCH
ALPINE_VERSION
ALPINE_BRANCH
```

### Package selection

Edit the package manifest generated by:

```text
build_crude_os.sh
```

### Desktop appearance

The XFCE configuration controls:

* Panels
* Dock
* Window manager
* Icons
* Fonts
* Wallpaper
* Rofi
* Whisker menu
* GTK appearance

### Boot menu

Boot entries can be modified through:

```text
crude-os/config/boot/grub.cfg
crude-os/config/boot/isolinux.cfg
```

---

## 🗺️ Roadmap

CrudeOS is still evolving. Possible future work includes:

* [ ] More reliable ISO generation
* [ ] Improved UEFI boot flow
* [ ] Better hardware compatibility
* [ ] More polished installer experience
* [ ] Dedicated CrudeOS package repository
* [ ] Automatic update infrastructure
* [ ] More custom applications
* [ ] Improved first-boot setup
* [ ] More complete system branding
* [ ] Release/version management
* [ ] CI-based ISO builds
* [ ] Automated ISO testing
* [ ] Documentation improvements

---

## ⚠️ Project Status

CrudeOS is an **experimental Linux distribution** and should not currently be considered a replacement for a mature production operating system.

Build scripts and configurations are actively subject to change.

Some components are experimental and may require adjustments depending on the host environment, Alpine package availability, hardware, or virtualization setup.

---

## 🤝 Contributing

Contributions, bug reports, ideas, and improvements are welcome.

### Suggested workflow

```bash
git clone https://github.com/Dev-Mehraj/CrudeOS.git
cd CrudeOS
```

Create a branch:

```bash
git checkout -b feature/my-feature
```

Make your changes, test them, and open a pull request.

---

## 📜 License

CrudeOS is currently provided as an **educational and experimental project**.

See the repository for the latest licensing information.

---

## 👨‍💻 Author

**Mehraj**

A student exploring Linux, programming, system development, and computer science through the creation of CrudeOS.

---

## 🌊 CrudeOS Aqua

```text
        ____                  _      ___  ____
       / ___|_ __ _   _  ___ | | ___/ _ \/ ___|
      | |   | '__| | | |/ _ \| |/ _ \ | | \___ \
      | |___| |  | |_| | (_) | |  __/ |_| |___) |
       \____|_|   \__, |\___/|_|\___|\___/|____/
                  |___/

                 C R U D E O S

          Lightweight. Custom. Experimental.
```

**CrudeOS — built on Alpine, shaped by the project.** 🌊
