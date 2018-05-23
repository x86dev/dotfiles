#!/bin/sh

sudo cat <<EOT >> /usr/share/applications/ripcd.desktop
[Desktop Entry]
Name=Rip CD
Comment=This will start the automated CD ripping process.
Exec=$HOME/.dotfiles/bin/cdrip.sh
TryExec=$HOME/.dotfiles/bin/cdrip.sh
MimeType=x-content/audio-cdda
Type=Application
EOT

cat <<EOT >> $HOME/.local/share/applications/mimeapps.list
[Default Applications]
x-content/audio-cdda=ripcd.desktop;
x-content/video-dvd=ripdvd.desktop;
x-content/video-bluray=ripbluray.desktop
[Added Associations]
x-content/audio-cdda=ripcd.desktop;
x-content/video-dvd=ripdvd.desktop;
x-content/video-bluray=ripbluray.desktop;
EOT
