#!/bin/sh

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
