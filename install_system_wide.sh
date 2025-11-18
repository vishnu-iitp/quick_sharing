#!/bin/bash
# Quick Share System-Wide Installation Script

echo "Installing Quick Share system-wide..."

# Create installation directory
sudo mkdir -p /opt/quick_sharing

# Copy application files
sudo cp -r build/linux/x64/release/bundle/* /opt/quick_sharing/

# Create system-wide desktop entry
sudo bash -c 'cat > /usr/share/applications/quick_sharing.desktop << "DESKTOP"
[Desktop Entry]
Name=Quick Sharing
Comment=Fast file sharing over local network
Exec=/opt/quick_sharing/quick_sharing
Icon=folder-download
Terminal=false
Type=Application
Categories=Network;FileTransfer;
DESKTOP'

# Update desktop database
sudo update-desktop-database /usr/share/applications/

# Make executable accessible
sudo chmod +x /opt/quick_sharing/quick_sharing

echo ""
echo "✓ Quick Share installed successfully to /opt/quick_sharing"
echo "✓ Desktop entry created in /usr/share/applications"
echo "✓ App is now available in your application menu for all users"
