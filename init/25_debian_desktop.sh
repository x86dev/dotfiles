#!/bin/sh

sudo add-apt-repository -y ppa:ubuntu-mozilla-security/ppa
sudo add-apt-repository -y ppa:pbek/qownnotes
sudo add-apt-repository -y ppa:nextcloud-devs/client
sudo add-apt-repository -y ppa:yubico/stable
sudo add-apt-repository -y ppa:sebastian-stenzel/cryptomator
sudo add-apt-repository -y ppa:phoerious/keepassxc

sudo apt-get update

sudo apt-get install -y keepassxc meld nautilus-compare nextcloud-client qownnotes thunderbird
