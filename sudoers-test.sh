#!/usr/bin/env bash

prompt_delay=5

# Installing this sudoers file makes life easier.
sudoers_dest=/etc/sudoers.d/sudoers-dotfiles
read -r -d '' sudoers_text <<'EOF'
# This file gets created in /etc/sudoers.d/ by the dotfiles script
# Reference: http://ubuntuforums.org/showthread.php?t=1132821

# Command aliases.
Cmnd_Alias APT = /usr/bin/apt-get

# Members of the sudo and admin groups can run these commands without password.
%sudo ALL=(ALL) ALL, NOPASSWD:APT
%admin ALL=(ALL) ALL, NOPASSWD:APT
EOF
if [[ ! -e $sudoers_dest || "$(cat $sudoers_dest)" != "$sudoers_text" ]]; then
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
    echo "# Updating sudoers"
    sudo bash -c "
      echo '$sudoers_text' | (EDITOR=tee visudo -f $sudoers_dest)
      && visudo -c && echo 'File $sudoers_dest updated.'
      || (rm $sudoers_dest && echo 'Unable to update $sudoers_dest file.')
    "
  else
    echo "Skipping."
  fi
fi
