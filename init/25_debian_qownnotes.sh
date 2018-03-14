# Debian-only stuff. Abort if not Debian.
is_debian || return 1

sudo add-apt-repository -y ppa:pbek/qownnotes
sudo apt-get update && sudo apt-get install -y qownnotes
