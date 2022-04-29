#!/bin/sh

# Install Visual Studio Code.
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt-get -qq update && sudo apt-get install -y code

# Set Visual Studio Code as default editor.
sudo update-alternatives --set editor /usr/bin/code
xdg-mime default code.desktop text/plain

# Install extensions
code --install-extension Shan.code-settings-sync
code --list-extensions
