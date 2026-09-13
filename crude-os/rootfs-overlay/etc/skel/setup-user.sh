#!/bin/sh
# Crude OS Default User Configuration
# This file sets up the default user environment

# Create default LIVE-SESSION user 'crudeos' with password 'crudeos'
# This account is only for the "Try Crude OS" live/demo session (autologin).
# It is NOT reused when installing — Calamares asks the installer to create
# a brand new username + password for the permanent install.

echo "Setting up Crude OS default configuration..."

# Add crudeos user
if ! id crudeos >/dev/null 2>&1; then
    adduser -D -s /bin/bash crudeos
    echo "crudeos:crudeos" | chpasswd 2>/dev/null || true
fi

# Set up user directories
mkdir -p /home/crudeos/{Documents,Downloads,Pictures,Videos,Music}
chown -R crudeos:crudeos /home/crudeos
chmod 755 /home/crudeos

# Copy skeleton files
cp -r /etc/skel/. /home/crudeos/ 2>/dev/null || true
chown -R crudeos:crudeos /home/crudeos

echo "Default live-session user 'crudeos' created (password: crudeos)"
echo "This is only for trying Crude OS live — installing creates a new account."
