#!/bin/sh

# Install restic.
MY_RESTIC_VER=0.9.5
MY_RESTIC_TMP=$(mktemp -d)
sh -c "$(wget -O $MY_RESTIC_TMP/restic.bz2 https://github.com/restic/restic/releases/download/v${MY_RESTIC_VER}/restic_${MY_RESTIC_VER}_linux_amd64.bz2)"
bunzip2 "$MY_RESTIC_TMP/restic.bz2"
chmod +x "$MY_RESTIC_TMP/restic"
sudo mv "$MY_RESTIC_TMP/restic" /usr/local/bin/
rm -rf "$MY_RESTIC_TMP"

# Install lazygit.
sudo add-apt-repository ppa:lazygit-team/release
sudo apt-get install lazygit

# Install Oh My Zsh.
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended --keep-zshrc"

# Make Zsh default.
chsh -s $(which zsh)

# Git tweaking.
# Security warning: Will store in *plaintext* on disk!
$(cd "$DOTFILES"; \
  git config --global credential.helper store; \
  git config remote.origin.push HEAD )
