#!/bin/sh

sudo add-apt-repository -y ppa:ubuntu-mozilla-security/ppa
sudo add-apt-repository -y ppa:pbek/qownnotes
sudo add-apt-repository -y ppa:nextcloud-devs/client
sudo add-apt-repository -y ppa:yubico/stable
sudo add-apt-repository -y ppa:sebastian-stenzel/cryptomator

sudo apt-get update

sudo apt-get install -y meld nautilus-compare nextcloud-client qownnotes thunderbird

# Install KeePass 2 + dependencies.
sudo apt-get install -y curl cryptomator keepass2 mono-mcs xsel xdotool yubikey-personalization

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

