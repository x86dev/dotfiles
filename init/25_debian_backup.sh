#!/bin/sh

resticctl_create_repo_template()
{
    MY_RESTIC_CFG_PATH=$1
    sudo mkdir -p "$MY_RESTIC_CFG_PATH"
    MY_REPO_NAME=$2
    MY_REPO_TEMPLATE="$MY_RESTIC_CFG_PATH/$MY_REPO_NAME.repo"

    if [ -f "$MY_REPO_TEMPLATE" ]; then
        return
    fi

    echo "Enter repository password to use and press [ENTER]: "
    stty -echo
    read MY_RESTIC_PASSWORD
    stty echo

    sudo cat > "$MY_REPO_TEMPLATE" <<EOF
# Repository configuration file for restic profile '$rname'
# Created at $(date) by $USER on $(uname -n)
#
# This file follows shell syntax:
#   1. Don't forget proper quoting where appropriate
#   2. Shell commands can be used (eg, subshells, variable expansion etc)
# restic repository and access options
RESTIC_REPOSITORY=rest:http://192.168.0.120:8000/$MY_REPO_NAME
RESTIC_PASSWORD=$MY_RESTIC_PASSWORD
EOF

  # Make sure to clear password.
  MY_RESTIC_PASSWORD=

  sudo chmod 600 "$MY_REPO_TEMPLATE"
}

resticctl_create_profile_template()
{
    MY_RESTIC_CFG_PATH=$1
    sudo mkdir -p "$MY_RESTIC_CFG_PATH"
    MY_PROFILE_NAME=$2
    MY_PROFILE_TEMPLATE="$MY_RESTIC_CFG_PATH/$MY_PROFILE_NAME.profile"

    if [ -f "$MY_PROFILE_TEMPLATE" ]; then
        return
    fi

    sudo cat > "$MY_PROFILE_TEMPLATE" <<EOF
# Configuration file for restic profile '$MY_PROFILE_NAME'
# Created at $(date) by $USER on $(uname -n)
#
# This file follows shell syntax:
#   1. Don't forget proper quoting where appropriate
#   2. Shell commands can be used (eg, subshells, variable expansion etc)
# name of the repository to use. use 'resticctl redit <name>' to create/edit
REPO=$MY_PROFILE_NAME
# all snapshots will be tagged with this string
RESTIC_TAG=$MY_PROFILE_NAME
# renice the backup process to this value
# learn more about nice by running 'man 1 nice'
RENICE=10
# what to backup and exclude
BACKUP_INCLUDE=(
  '/home'
  '/etc'
  '/srv'
)
BACKUP_EXCLUDE=(
  '*.tmp'
)
# if you need to run commands before or after the backup, specify them here
# for example, running a backup of a database to a file
PRE_HOOKS=(
  'dev_nas_wol 10'
)
#POST_HOOKS=(
#)
# additional arguments to pass to restic when creating backups
RESTIC_ARGS='--exclude-caches'
# comment whole line to disable the flag.
KEEP_LAST=3
#KEEP_HOURLY=
KEEP_DAILY=7
KEEP_WEEKLY=5
KEEP_MONTHLY=12
KEEP_YEARLY=2
EOF

    sudo chmod 600 "$MY_PROFILE_TEMPLATE"
}

resticctl_init_repo()
{
    MY_RESTIC_CFG_PATH=$1
    MY_REPO_NAME=$2

    sudo dev_nas_wol 10
    sudo resticctl init "$MY_RESTIC_REPO_NAME"
}

systemd_install_timer()
{
    # Note: The --now makes sure the timer gets active WITHOUT a reboot.
    sudo systemctl enable --now $1@${MY_RESTIC_REPO_NAME}.timer
    sudo systemctl restart timers.target
    sudo systemctl status $1@${MY_RESTIC_REPO_NAME}.timer
}

# Install required dependencies.
sudo apt-get install -y rsync etherwake bzip2

# Install restic.
MY_RESTIC_REPO_NAME=$(hostname)
MY_RESTIC_DIR_BIN=/usr/local/bin
MY_RESTIC_DIR_TMP=$(mktemp -d)
if [ ! -f "$MY_RESTIC_DIR_BIN/restic" ]; then
    MY_RESTIC_VER=0.12.1
    sh -c "$(wget -O "$MY_RESTIC_DIR_TMP/restic.bz2" https://github.com/restic/restic/releases/download/v${MY_RESTIC_VER}/restic_${MY_RESTIC_VER}_linux_amd64.bz2)"
    bunzip2 "$MY_RESTIC_DIR_TMP/restic.bz2"
    sudo install -m 755 "$MY_RESTIC_DIR_TMP/restic" "$MY_RESTIC_DIR_BIN/restic"
fi
sudo restic self-update

# Install restic wrapper script (resticctl, see https://github.com/fukawi2/resticctl).
sh -c "$(wget -P "$MY_RESTIC_DIR_TMP" https://raw.githubusercontent.com/fukawi2/resticctl/master/resticctl.sh)"
sudo install -m 0755 "$MY_RESTIC_DIR_TMP"/resticctl.sh "$MY_RESTIC_DIR_BIN/resticctl"

if [ -n "$(which systemd)" ]; then
    # Install systemd services + timers.
    # Yeah, excellent idea to install remote scripts right into our systemd service dir. Don't try this at home, kids.
    MY_SYSTEMD_SYS_DIR=/etc/systemd/system/
    sh -c "$(wget -P "$MY_RESTIC_DIR_TMP" https://raw.githubusercontent.com/fukawi2/resticctl/master/restic%40.service)"
    sh -c "$(wget -P "$MY_RESTIC_DIR_TMP" https://raw.githubusercontent.com/fukawi2/resticctl/master/restic%40.timer)"
    sh -c "$(wget -P "$MY_RESTIC_DIR_TMP" https://raw.githubusercontent.com/fukawi2/resticctl/master/restic-cleanup%40.service)"
    sh -c "$(wget -P "$MY_RESTIC_DIR_TMP" https://raw.githubusercontent.com/fukawi2/resticctl/master/restic-cleanup%40.timer)"
    sudo install -m 644 "$MY_RESTIC_DIR_TMP/restic*.service" "$MY_RESTIC_DIR_TMP/restic*.timer" "$MY_SYSTEMD_SYS_DIR"

    systemd_install_timer "restic"
    systemd_install_timer "restic-cleanup"
fi

# Initialize repo.
MY_REPO_DO_INIT=
sudo resticctl $MY_RESTIC_REPO_NAME
if [ $? -ne "0" ]; then
    MY_REPO_DO_INIT=1
fi
if [ -n "$MY_REPO_DO_INIT" ]; then
    resticctl_create_repo_template "/etc/restic/" "$MY_RESTIC_REPO_NAME"
    resticctl_create_profile_template "/etc/restic/" "$MY_RESTIC_REPO_NAME"
    resticctl_init_repo "$MY_RESTIC_CFG_PATH" "$MY_RESTIC_REPO_NAME"
fi

# Cleanup.
rm -rf "$MY_RESTIC_DIR_TMP"
