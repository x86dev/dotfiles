# Ubuntu-only stuff. Abort if not Ubuntu.
is_ubuntu || return 1

# Update APT.
e_header "Updating APT"
sudo apt-get -qq update

# Only do a dist-upgrade on initial install.
if [[ "$new_dotfiles_install" ]]; then
  sudo apt-get -qq dist-upgrade
else
  sudo apt-get -qq upgrade
fi

# Add APT keys.
keys=(
  https://dl-ssl.google.com/linux/linux_signing_key.pub
)

keys_cache=$DOTFILES/caches/apt_keys
IFS=$'\n' GLOBIGNORE='*' command eval 'keys_exist=($(<$keys_cache))'
keys=($(setdiff "${keys[*]}" "${keys_exist[*]}"))

if (( ${#keys[@]} > 0 )); then
  e_header "Adding APT keys: ${keys[*]}"
  for key in "${keys[@]}"; do
    wget -qO- $key | sudo apt-key add - && echo $key >> $keys_cache
  done
fi

# Install APT packages.
packages=(
  ansible
  build-essential
  cowsay
  curl
  git-core
  htop
  id3tool
  jq
  libssl-dev
  mercurial
  nmap
  silversearcher-ag
  sl
  telnet
  tree
  vim
)

is_ubuntu_desktop && packages+=(
  chromium-browser
  k4dirstat
  rofi
  shutter
  transgui
  vim-gnome
  vlc
)

packages=($(setdiff "${packages[*]}" "$(dpkg --get-selections | grep -v deinstall | awk '{print $1}')"))

if (( ${#packages[@]} > 0 )); then
  e_header "Installing APT packages: ${packages[*]}"
  for package in "${packages[@]}"; do
    sudo apt-get -qq install "$package"
  done
fi

# Install Git Extras
if [[ ! "$(type -P git-extras)" ]]; then
  e_header "Installing Git Extras"
  (
    cd $DOTFILES/vendor/git-extras &&
    sudo make install
  )
fi
