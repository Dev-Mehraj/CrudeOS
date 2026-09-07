#!/bin/sh
# Crude OS Default User Configuration
# This file sets up the default user environment

# Create default user 'crude' with password 'crude'
# (User will be prompted to change on first login in actual deployment)

echo "Setting up Crude OS default configuration..."

# Add crude user
if ! id crude >/dev/null 2>&1; then
    adduser -D -s /bin/bash crude
    echo "crude:crude" | chpasswd 2>/dev/null || true
fi

# Set up user directories
mkdir -p /home/crude/{Documents,Downloads,Pictures,Videos,Music}
chown -R crude:crude /home/crude
chmod 755 /home/crude

# Copy skeleton files
cp -r /etc/skel/. /home/crude/ 2>/dev/null || true
chown -R crude:crude /home/crude

echo "Default user 'crude' created (password: crude)"
echo "Please change the password after first login!"
