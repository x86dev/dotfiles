# Debian-only stuff. Abort if not Debian.
is_debian || return 1

#!/bin/sh
# Install required dependencies.
sudo apt-get install -y duplicity rsync ca-cacert
