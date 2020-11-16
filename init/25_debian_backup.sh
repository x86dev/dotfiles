#!/bin/sh

# Install required dependencies.
sudo apt-get install -y rsync etherwake

# Install restic.
MY_RESTIC_REPO_NAME=$(hostname)
MY_RESTIC_DIR_BIN=/usr/local/bin
MY_RESTIC_DIR_TMP=$(mktemp -d)
MY_RESTIC_VER=0.11.0
sh -c "$(wget -O "$MY_RESTIC_DIR_TMP/restic.bz2" https://github.com/restic/restic/releases/download/v${MY_RESTIC_VER}/restic_${MY_RESTIC_VER}_linux_amd64.bz2)"
bunzip2 "$MY_RESTIC_DIR_TMP/restic.bz2"
sudo install -m 755 "$MY_RESTIC_DIR_TMP/restic" "$MY_RESTIC_DIR_BIN/restic"
sudo restic self-update

# Install restic wrapper script (resticctl, see https://github.com/fukawi2/resticctl).
sh -c "$(wget -P "$MY_RESTIC_DIR_TMP" https://raw.githubusercontent.com/fukawi2/resticctl/master/resticctl.sh)"
sudo install -m 0755 "$MY_RESTIC_DIR_TMP"/resticctl.sh "$MY_RESTIC_DIR_BIN/resticctl"

# Install systemd services + timers.
# Yeah, excellent idea to install remote scripts right into our systemd service dir. Don't try this at home, kids.
MY_SYSTEMD_SYS_DIR=/etc/systemd/system/
sh -c "$(wget -P "$MY_RESTIC_DIR_TMP" https://raw.githubusercontent.com/fukawi2/resticctl/master/restic%40.service)"
sh -c "$(wget -P "$MY_RESTIC_DIR_TMP" https://raw.githubusercontent.com/fukawi2/resticctl/master/restic%40.timer)"
sh -c "$(wget -P "$MY_RESTIC_DIR_TMP" https://raw.githubusercontent.com/fukawi2/resticctl/master/restic-cleanup%40.service)"
sh -c "$(wget -P "$MY_RESTIC_DIR_TMP" https://raw.githubusercontent.com/fukawi2/resticctl/master/restic-cleanup%40.timer)"
sudo install -m 644 "$MY_RESTIC_DIR_TMP"/restic*.service "$MY_RESTIC_DIR_TMP"/restic*.timer "$MY_SYSTEMD_SYS_DIR"
sudo systemctl enable restic@${MY_RESTIC_REPO_NAME}.timer
sudo systemctl start restic@${MY_RESTIC_REPO_NAME}.timer
sudo systemctl enable restic-cleanup@${MY_RESTIC_REPO_NAME}.timer
sudo systemctl start restic-cleanup@${MY_RESTIC_REPO_NAME}.timer

# Initialize repo.
sudo resticctl redit "$MY_RESTIC_REPO_NAME"
sudo resticctl edit "$MY_RESTIC_REPO_NAME"
sudo resticctl init "$MY_RESTIC_REPO_NAME"

# Cleanup.
rm -rf "$MY_RESTIC_DIR_TMP"
