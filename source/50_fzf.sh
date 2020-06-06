MY_FZF=${DOTFILES}/vendor/fzf

if [[ ! "$PATH" == *$MY_FZF/bin* ]]; then
  export PATH="$PATH:$MY_FZF/bin"
fi

# Auto-completion.
[[ $- == *i* ]] && source "$MY_FZF/shell/completion.bash" 2> /dev/null

# Key bindings.
source "$MY_FZF/shell/key-bindings.$(basename $SHELL)"

# Customization
export FZF_DEFAULT_OPTS='--height 40% --border'
