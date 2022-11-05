#!/bin/sh

MY_LOCAL_BIN="$HOME/.local/bin/"
mkdir -p "$MY_LOCAL_BIN"

# Install fzf.
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install

# Install lazygit + delta.
MY_FLAVOR=${MY_OS}_$(uname -m); curl -s -L $(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep browser_download_url | cut -d '"' -f 4 | grep -i "$MY_FLAVOR") | tar xzf - -C "$MY_LOCAL_BIN" lazygit
MY_FLAVOR=$(uname -m)-unknown-*${MY_OS}-gnu; curl -s -L $(curl -s https://api.github.com/repos/dandavison/delta/releases/latest | grep browser_download_url | cut -d '"' -f 4 | grep -i "$MY_FLAVOR") | tar xzf - --strip-components=1 -C "$MY_LOCAL_BIN" --wildcards "*/delta"

# Install Oh My Zsh.
sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended --keep-zshrc"

# Make Zsh default.
chsh -s $(which zsh)

# Git tweaking.
# Security warning: Will store in *plaintext* on disk!
$(cd "$DOTFILES"; \
  git config --global credential.helper store; \
  git config remote.origin.push HEAD )

# Install latest tldr
curl -o "$MY_LOCAL_BIN/tldr" https://raw.githubusercontent.com/raylee/tldr/master/tldr && chmod +x "$MY_LOCAL_BIN/tldr"
