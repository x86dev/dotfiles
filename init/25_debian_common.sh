#!/bin/sh

# TODO
# Install restic, lazygit

# Install Oh My Zsh.
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended --keep-zshrc"

# Git tweaking.
# Security warning: Will store in *plaintext* on disk!
git config --global credential.helper store

