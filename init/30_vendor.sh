# Install dircolors.
ln -sf ${DOTFILES}/vendor/dircolors-solarized ${HOME}/.dircolors

# Link solarized color scheme for Vim.
ln -sf ${DOTFILES}/vendor/vim-colors-solarized/ ${HOME}/.vim/bundle/vim-colors-solarized

# Install fzf.
## @todo Build fzf from scratch (Go required) instead of downloading the binary?
${DOTFILES}/vendor/fzf/install --bin --key-bindings --completion --no-update-rc
