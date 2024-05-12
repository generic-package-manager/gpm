#!/bin/bash

# GPM Installer
# v1.0.0

# Greetings
echo "Hello There!"
echo "Welcome to GPM Installer."
sleep 1

# Creating gpm directory structure
echo "Creating gpm directory structure ..."
echo "Creating ~/.gpm ..."
mkdir ~/.gpm
echo "Creating ~/.gpm/apps ..."
mkdir ~/.gpm/apps/
echo "Creating gpm binary home directory ..."
mkdir ~/.gpm/apps/generic-package-manager
mkdir ~/.gpm/apps/generic-package-manager/gpm

# Creating registry structure
echo "Creating registry structure ..."
echo "Creating ~/.gpm/registry ..."
mkdir ~/.gpm/registry/
echo "Creating gpm registry home directory ..."
mkdir ~/.gpm/registry/generic-package-manager


# Starting to download gpm
echo "Finding the latest gpm release on GitHub ..."
echo "Downloading gpm ..."
wget https://github.com/generic-package-manager/gpm/releases/latest/download/gpm.AppImage --output-document=$HOME/.gpm/apps/generic-package-manager/gpm/gpm
chmod +x ~/.gpm/apps/generic-package-manager/gpm/gpm
~/.gpm/apps/generic-package-manager/gpm/gpm --version

# Pulling Registry Information
echo "Pulling Registry Information ..."
echo "This will make gpm updatable using gpm itself ;)"
wget -q https://raw.githubusercontent.com/generic-package-manager/gpm/master/pyro/linux/registry/gpm.json --output-document=$HOME/.gpm/registry/generic-package-manager/gpm.json

# Putting gpm on PATH
echo "Putting gpm on PATH ..."
gpm
gpm_path="$HOME/.gpm/apps/generic-package-manager/gpm"

# Check if gpm is already on PATH
if command -v gpm &> /dev/null; then
    echo "gpm is already on PATH."
else
    # Add gpm to PATH
    export PATH="\$PATH:$gpm_path"
    echo "PATH=\"\$PATH:$gpm_path\"" >> "$HOME/.$(basename "$SHELL")rc"
    echo "Added gpm to PATH."
fi

# Verify if gpm is now on PATH
if command -v gpm &> /dev/null; then
    echo "gpm is on PATH."

    # Checking for updates
    gpm --update generic-package-manager/gpm

    # Conclusion
    echo "Done! gpm is now installed on your system."
else
    echo "Failed to add gpm to PATH. Please check the installation."
    echo "Done! gpm is now present on your system, but you may have to add it to PATH manually."
fi
