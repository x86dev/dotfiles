# Debian-only stuff. Abort if not Debian.
is_debian || return 1

#!/bin/sh
set -e

# Spotify
sudo sh -c 'echo "deb http://repository.spotify.com stable non-free" > /etc/apt/sources.list.d/spotify.list'
curl -sS https://download.spotify.com/debian/pubkey_0D811D58.gpg | sudo apt-key add -
sudo apt-get update
sudo apt-get install -y spotify-client

# VLC
sudo snap install vlc

# XnViewMP
curl https://download.xnview.com/XnViewMP-linux-x64.deb -o /tmp/xnview-mp.deb && sudo dpkg -i /tmp/xnview-mp.deb; rm /tmp/xnview-mp.deb

# Gnome Extensions
sudo apt-get install -y chrome-gnome-shell gir1.2-gtop-2.0 gir1.2-networkmanager-1.0  gir1.2-clutter-1.0
