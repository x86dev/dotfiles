# Ubuntu-only stuff. Abort if not Ubuntu.
is_ubuntu || return 1

#!/bin/sh
# Install required dependencies.
sudo apt-get install -y duplicity rsync ca-cacert
