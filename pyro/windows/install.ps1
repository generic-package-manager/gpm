
# @echo off

# GPM Installer
# v1.0.0

# Greetings
echo "Hello There!"
echo "Welcome to GPM Installer."
pwsh -nop -c "& {sleep 1}"

echo $HOME

# Creating gpm directory structure
echo "Creating gpm directory structure ..."
echo "Creating ~/.gpm ..."
mkdir $HOME\.gpm
echo "Creating ~/.gpm/apps ..."
mkdir $HOME\.gpm\apps\
echo "Creating gpm binary home directory ..."
mkdir $HOME\.gpm\apps\generic-package-manager
mkdir $HOME\.gpm\apps\generic-package-manager\gpm

# Creating registry structure
echo "Creating registry structure ..."
echo "Creating ~/.gpm/registry ..."
mkdir $HOME\.gpm\registry\
echo "Creating gpm registry home directory ..."
mkdir $HOME\.gpm\registry\generic-package-manager

# Starting to download gpm
echo "Finding the latest gpm release on GitHub ..."
echo "Downloading gpm ..."
pwsh -NoProfile -ExecutionPolicy Bypass -Command "& { Invoke-WebRequest -Uri 'https://github.com/generic-package-manager/gpm/releases/latest/download/gpm.exe' -OutFile '$HOME\.gpm\apps\generic-package-manager\gpm\gpm.exe' }"
echo "Downloading gpm update helper ..."
pwsh -NoProfile -ExecutionPolicy Bypass -Command "& { Invoke-WebRequest -Uri 'https://github.com/generic-package-manager/gpm/releases/latest/download/gpm-binary-replacer.exe' -OutFile '$HOME\.gpm\apps\generic-package-manager\gpm\gpm-binary-replacer.exe' }"
Start-Process -FilePath $HOME/.gpm/apps/generic-package-manager/gpm/gpm.exe -ArgumentList "--version" -Wait -NoNewWindow

# Pulling Registry Information
echo "Pulling Registry Information ..."
echo "This will make gpm updatable using gpm itself."
pwsh -NoProfile -ExecutionPolicy Bypass -Command "& { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/generic-package-manager/gpm/master/pyro/windows/registry/gpm.json' -OutFile '$HOME\.gpm\registry\generic-package-manager\gpm.json' }"

# Putting gpm on PATH

echo "To ensure security on your windows operating system, "
echo "gpm will not itself update the path variable."
echo "Please add $HOME\.gpm\apps\generic-package-manager\gpm to your System Environment Variable to access the installed cli program throughtout your system."

# Conclusion
echo "Done! gpm is now present on your system, you just have to update your PATH variable."