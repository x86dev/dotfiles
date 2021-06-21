#!/bin/sh

sudo add-apt-repository -y ppa:ubuntu-mozilla-security/ppa
sudo add-apt-repository -y ppa:nextcloud-devs/client
sudo add-apt-repository -y ppa:yubico/stable
sudo add-apt-repository -y ppa:sebastian-stenzel/cryptomator
sudo add-apt-repository -y ppa:phoerious/keepassxc

sudo apt-get update

sudo apt-get install -y keepassxc meld nautilus-compare nautilus-nextcloud thunderbird

#
# Upgrade lists:
# sed -i -E "s/cosmic|disco|eoan|focal/$(lsb_release -cs)/" *.list
# sed -i -E "s/^# \(.*\) # disabled on upgrade to.*/\1/g" *.list
#
