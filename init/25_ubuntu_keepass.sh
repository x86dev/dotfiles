# Debian-only stuff. Abort if not Debian.
is_debian || return 1

#!/bin/sh
# Install KeePass 2 + dependencies.
sudo apt-get install -y keepass2 mono mono-dmcs xsel xdotool
