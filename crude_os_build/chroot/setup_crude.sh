#!/bin/sh
set -e

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

echo "Crude OS system configured."
