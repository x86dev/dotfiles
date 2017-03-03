#!/usr/bin/env bash

prompt_delay=5

# Installing this sudoers file makes life easier.
sudoers_dest=/etc/sudoers.d/sudoers-dotfiles
# Contents of the sudoers file.
read -r -d '' sudoers_text <<EOF
# This file was created by the dotfiles script on $(date)
# (which will never update it, only recreate it if it's missing)
# Reference: http://ubuntuforums.org/showthread.php?t=1132821

# Command aliases.
Cmnd_Alias APT = /usr/bin/apt-get

# Members of the sudo and admin groups can run these commands without password.
%sudo ALL=(ALL) ALL, NOPASSWD:APT
%admin ALL=(ALL) ALL, NOPASSWD:APT
EOF
current_text="$(cat $sudoers_dest 2>/dev/null)"
# Bash commands to update the sudoers file.
read -r -d '' sudoers_code <<EOF
echo "$sudoers_text" > $sudoers_dest
chmod 0440 $sudoers_dest
if visudo -c; then
  echo; echo "File $sudoers_dest created."
else
  if [[ "$current_text" ]]; then
    echo "$current_text" > $sudoers_dest
  else
    rm $sudoers_dest
  fi
  echo; echo "Unable to create $sudoers_dest file."
fi
EOF
# Actually update the sudoers file if necessary.
if [[ ! -e $sudoers_dest ]]; then
  cat <<EOF
The sudoers file can be updated to allow "sudo apt-get" to be executed
without asking for a password. You can verify that this worked correctly by
running "sudo -k apt-get". If it doesn't ask for a password, and the output
looks normal, it worked.

THIS SHOULD ONLY BE ATTEMPTED IF YOU ARE LOGGED IN AS ROOT IN ANOTHER SHELL.

This will be skipped if "Y" isn't pressed within the next $prompt_delay seconds.
EOF
  read -N 1 -t $prompt_delay -p "Update sudoers file? [y/N] " update_sudoers; echo
  if [[ "$update_sudoers" =~ [Yy] ]]; then
    echo "# Creating sudoers file"
    echo
    sudo bash -c "$sudoers_code"
  else
    echo "Skipping."
  fi
fi
