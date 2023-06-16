FZF_BASE=${HOME}/opt/fzf

if [[ ! "$PATH" == *$FZF_BASE* ]]; then
  export PATH="$PATH:$FZF_BASE"
fi

# Auto-completion.
#[[ $- == *i* ]] && source "$FZF_BASE/shell/completion.$MY_SHELL" 2> /dev/null

# Key bindings.
source "$FZF_BASE/shell/key-bindings.$MY_SHELL"

# Customization
export FZF_DEFAULT_OPTS='--height 40% --border'
