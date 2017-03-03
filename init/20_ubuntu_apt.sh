# Ubuntu-only stuff. Abort if not Ubuntu.
is_ubuntu || return 1

# Update APT.
e_header "Updating APT"
sudo apt-get -qq update
sudo apt-get -qq dist-upgrade

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
