#!/bin/sh

# Install required dependencies.
sudo apt-get install -y rsync

# Install restic.
MY_RESTIC_TMP=$(mktemp -d)
MY_RESTIC_VER=0.11.0
sh -c "$(wget -O $MY_RESTIC_TMP/restic.bz2 https://github.com/restic/restic/releases/download/v${MY_RESTIC_VER}/restic_${MY_RESTIC_VER}_linux_amd64.bz2)"
bunzip2 "$MY_RESTIC_TMP/restic.bz2"
sudo install -m 755 "$MY_RESTIC_TMP/restic" /usr/local/bin/
sudo restic self-update

# Install restic wrapper script (runrestic, see https://github.com/sinnwerkstatt/runrestic).
sudo apt-get install -y python3 python3-pip
sudo pip3 install --upgrade runrestic
# ASSUMES systemd. D'oh.
# Yeah, excellent idea to install remote scripts right into our systemd service dir. Don't try this at home, kids.
MY_SYSTEMD_SYS_DIR=/etc/systemd/system/
sh -c "$(wget -P "$MY_RESTIC_TMP" https://raw.githubusercontent.com/sinnwerkstatt/runrestic/master/sample/systemd/runrestic.service)"
sh -c "$(wget -P "$MY_RESTIC_TMP" https://raw.githubusercontent.com/sinnwerkstatt/runrestic/master/sample/systemd/runrestic.timer)"
sudo install -m 644 "$MY_RESTIC_TMP/runrestic.service" "$MY_RESTIC_TMP/runrestic.timer" "$MY_SYSTEMD_SYS_DIR"
sudo systemctl enable runrestic.timer
sudo systemctl start runrestic.timer

# Cleanup.
rm -rf "$MY_RESTIC_TMP"
