# Installs homebrew from github.
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

# Load homebrew into current shell.
eval "$(/opt/homebrew/bin/brew shellenv)"

# Uncomment if you need any proxy set.
#export ALL_PROXY=${http_proxy}
#export ALL_PROXY=http://my-proxy.domain.com:80

# Install stuff.
brew doctor
brew install fzf htop git lazygit ncdu tmux zsh