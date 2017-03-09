# Ubuntu-only stuff. Abort if not Ubuntu.
is_ubuntu || return 1

# Ubuntu distro release name, eg. "xenial"
release_name=$(lsb_release -c | awk '{print $2}')

# Add APT keys.
keys=()

is_ubuntu_desktop && keys+=(
  # https://www.ubuntuupdates.org/ppa/google_chrome
  https://dl-ssl.google.com/linux/linux_signing_key.pub
  # https://www.charlesproxy.com/documentation/installation/apt-repository/
  https://www.charlesproxy.com/packages/apt/PublicKey
  # https://github.com/aluxian/Messenger-for-Desktop#linux
  '--keyserver pool.sks-keyservers.net --recv 6DDA23616E3FE905FFDA152AE61DA9241537994D'
  # https://www.spotify.com/us/download/linux/
  '--keyserver hkp://keyserver.ubuntu.com:80 --recv-keys BBEBDCB318AD50EC6865090613B00F1FD2C19886'
  # https://tecadmin.net/install-oracle-virtualbox-on-ubuntu/
  https://www.virtualbox.org/download/oracle_vbox_2016.asc
)

keys_cache=$DOTFILES/caches/init/apt_keys
IFS=$'\n' GLOBIGNORE='*' command eval 'setdiff_cur=($(<$keys_cache))'
setdiff_new=("${keys[@]}"); setdiff; keys=("${setdiff_out[@]}")
unset setdiff_new setdiff_cur setdiff_out

if (( ${#keys[@]} > 0 )); then
  e_header "Adding APT keys (${#keys[@]})"
  for key in "${keys[@]}"; do
    e_arrow "$key"
    if [[ "$key" =~ -- ]]; then
      sudo apt-key adv $key
    else
      wget -qO- $key | sudo apt-key add -
    fi && echo "$key" >> $keys_cache
  done
fi

# Add APT sources
function add_ppa() {
  source_texts+=($1)
  IFS=':/' eval 'local parts=($1)'
  source_files+=("${parts[1]}-ubuntu-${parts[2]}-$release_name")
}

source_files=()
source_texts=()
add_ppa ppa:stebbins/handbrake-releases

if is_ubuntu_desktop; then
  add_ppa ppa:rael-gc/scudcloud
  add_ppa ppa:webupd8team/y-ppa-manager
  source_files+=(
    aluxian
    charles
    google-chrome
    spotify
    virtualbox
  )
  source_texts+=(
    "deb https://dl.bintray.com/aluxian/deb/ beta main"
    "deb https://www.charlesproxy.com/packages/apt/ charles-proxy3 main"
    "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main"
    "deb http://repository.spotify.com stable non-free"
    "deb http://download.virtualbox.org/virtualbox/debian $release_name contrib"
  )
fi

function __temp() { [[ ! -e /etc/apt/sources.list.d/$1.list ]]; }
source_i=($(array_filter_i source_files __temp))

if (( ${#source_i[@]} > 0 )); then
  e_header "Adding APT sources (${#source_i[@]})"
  for i in "${source_i[@]}"; do
    source_file=${source_files[i]}
    source_text=${source_texts[i]}
    if [[ "$source_text" =~ ppa: ]]; then
      e_arrow "$source_text"
      sudo add-apt-repository -y $source_text
    else
      e_arrow "$source_file"
      sudo sh -c "echo '$source_text' > /etc/apt/sources.list.d/$source_file.list"
    fi
  done
fi

# Update APT.
e_header "Updating APT"
sudo apt-get -qq update

# Only do a dist-upgrade on initial install, otherwise do an upgrade.
if is_dotfiles_bin; then
  sudo apt-get -qq upgrade
else
  sudo apt-get -qq dist-upgrade
fi

# Install APT packages.
packages=(
  # https://github.com/rbenv/ruby-build/wiki
  autoconf
  bison
  build-essential
  libssl-dev
  libyaml-dev
  libreadline6-dev
  libncurses5-dev
  libffi-dev
  libgdbm3
  libgdbm-dev
  zlib1g-dev
  # Mine
  ansible
  build-essential
  byobu
  cowsay
  curl
  git-core
  handbrake-cli
  htop
  id3tool
  imagemagick
  jq
  mercurial
  nmap
  silversearcher-ag
  sl
  telnet
  tree
  vim
)

is_ubuntu_desktop && packages+=(
  # https://github.com/colinkeenan/silentcast/#ubuntu
  libav-tools
  x11-xserver-utils
  xdotool
  wininfo
  wmctrl
  python-gobject
  python-cairo
  xdg-utils
  yad
  # Mine
  charles-proxy
  chromium-browser
  fonts-mplus
  google-chrome-stable
  handbrake-gtk
  k4dirstat
  messengerfordesktop
  python-gtk2
  python-gpgme
  rofi
  scudcloud
  shutter
  spotify-client
  transgui
  vim-gnome
  virtualbox-5.1
  vlc
)

# https://github.com/raelgc/scudcloud#ubuntukubuntu-and-mint
function preinstall_scudcloud() {
  echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections
}
function postinstall_scudcloud() {
  sudo dpkg-divert --add --rename --divert /usr/share/pixmaps/scudcloud.png.real /usr/share/pixmaps/scudcloud.png
  sudo cp $DOTFILES/conf/ubuntu/scudcloud.png /usr/share/pixmaps/
  sudo chmod +r /usr/share/pixmaps/scudcloud.png
  sudo update-desktop-database
}

packages=($(setdiff "${packages[*]}" "$(dpkg --get-selections | grep -v deinstall | awk '{print $1}')"))

if (( ${#packages[@]} > 0 )); then
  e_header "Installing APT packages (${#packages[@]})"
  for package in "${packages[@]}"; do
    e_arrow "$package"
    [[ "$(type -t preinstall_$package)" == function ]] && preinstall_$package
    sudo apt-get -qq install "$package" && \
    [[ "$(type -t postinstall_$package)" == function ]] && postinstall_$package
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

# Install debs via dpkg
debs=()
installed_file=()

if is_ubuntu_desktop; then
  debs+=(
    # https://support.gitkraken.com/how-to-install
    https://release.gitkraken.com/linux/gitkraken-amd64.deb
    # https://www.dropbox.com/install-linux
    "https://www.dropbox.com/download?dl=packages/ubuntu/dropbox_2015.10.28_amd64.deb"
    # https://github.com/raelgc/scudcloud#ubuntukubuntu-and-mint
    # http://askubuntu.com/a/852727
    http://ftp.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.6_all.deb
  )
  # The existence of these files signifies the package was installed
  installed_file+=(
    /usr/bin/gitkraken
    /usr/bin/dropbox
    /usr/share/fonts/truetype/msttcorefonts
  )
fi

function __temp() { [[ ! -e "$1" ]]; }
installed_file_i=($(array_filter_i installed_file __temp))

if (( ${#installed_file_i[@]} > 0 )); then
  installers_path="$DOTFILES/caches/installers"
  mkdir -p "$installers_path"
  e_header "Installing deb installed_file (${#installed_file_i[@]})"
  for i in "${installed_file_i[@]}"; do
    e_arrow "${installed_file[i]}"
    deb="${debs[i]}"
    installer_file="$installers_path/$(echo "$deb" | sed 's#.*/##')"
    wget -O "$installer_file" "$deb"
    sudo dpkg -i "$installer_file"
  done
fi
