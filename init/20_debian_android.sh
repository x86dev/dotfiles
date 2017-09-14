# Debian-only stuff. Abort if not Debian.
is_debian || return 1

e_header "udev Android rules"

sudo install -m644 \
    "$DOTFILES/bin/etc/udev/rules.d/51-android.rules" "/etc/udev/rules.d/51-android.rules"

sudo service udev restart
