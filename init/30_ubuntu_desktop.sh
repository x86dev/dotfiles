# Ubuntu-desktop-only stuff. Abort if not Ubuntu desktop.
is_ubuntu_desktop || return 1

echo "UBUNTU DESKTOP"
echo "new_dotfiles_install: <$new_dotfiles_install>"
