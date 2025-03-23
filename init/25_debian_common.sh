#!/bin/sh

MY_LOCAL_BIN="$HOME/.local/bin/"
mkdir -p "$MY_LOCAL_BIN"

# Install fzf.
MY_FZF_DIR=$HOME/opt/fzf
MY_FZF_REPO=https://github.com/junegunn/fzf.git
if [ ! -d "$MY_FZF_DIR" ]; then
    git clone --depth 1 "$MY_FZF_REPO" "$MY_FZF_DIR"
fi
$(cd "$MY_FZF_DIR" && git pull ${MY_FZF_REPO} && ${MY_FZF_DIR}/install --all)

# Install lazygit + delta.
# Note: There is no "wsl" version for those, so we tweak $MY_OS accordingly.
if [ "$MY_OS" = "wsl" ]; then
    MY_OS=linux
fi
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

# Install latest tldr.
curl -o "$MY_LOCAL_BIN/tldr" https://raw.githubusercontent.com/raylee/tldr/master/tldr && chmod +x "$MY_LOCAL_BIN/tldr"

# Install latest cheat sheet.
curl -o "$MY_LOCAL_BIN/cht.sh" https://cht.sh/:cht.sh && chmod +x "$MY_LOCAL_BIN/cht.sh"
