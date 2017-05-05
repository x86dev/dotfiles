# Ubuntu-only stuff. Abort if not Ubuntu.
is_ubuntu || return 1

#!/bin/sh
# Install Visual Studio Code.
sudo curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt-get update && apt-get install -y code
