# Debian-only stuff. Abort if not Debian.
#is_debian || return 1

#!/bin/sh
# Install KeePass 2 + dependencies.
sudo apt-get install -y curl keepass2 mono-dmcs xsel xdotool

# Install Yubico Personalization Tools.
# This is required for the KeeChallenge plugin.
sudo add-apt-repository -y ppa:yubico/stable
sudo apt-get update && sudo apt-get install -y yubikey-personalization

# Install KeeChallenge plugin (needed for YubiKey).
sudo mkdir -p /usr/lib/keepass2/plugins/
MY_PLUGIN_VER=1.5
MY_PLUGIN_ZIP=https://github.com/brush701/keechallenge/releases/download/${MY_PLUGIN_VER}/KeeChallenge_${MY_PLUGIN_VER}.zip
MY_PLUGIN_SHA1SUM=06c3b96ed674e5617f0daff5101e23ef95aff71c # Why no SHA256?
sudo curl -L ${MY_PLUGIN_ZIP} -o /tmp/keechallenge.zip
MY_DL_SHA1SUM=$(sha1sum /tmp/keechallenge.zip | cut -d' ' -f1)
if [ ${MY_PLUGIN_SHA1SUM} = "$MY_DL_SHA1SUM" ]; then
    sudo unzip /tmp/keechallenge.zip -d /usr/lib/keepass2/plugins/
else
    echo "Checksum does not match! Aborting."
    exit 1
fi
sudo rm /tmp/keechallenge.zip
