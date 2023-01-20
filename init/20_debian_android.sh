
e_header "udev Android rules"

sudo install -m644 \
    "$DOTFILES/bin/etc/udev/rules.d/51-android.rules" "/etc/udev/rules.d/51-android.rules"

sudo apt-get install -y mtp-tools

sudo service udev restart
