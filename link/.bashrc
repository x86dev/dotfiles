# Where the magic happens.
export DOTFILES=~/.dotfiles
export DOTFILES_PRIV=~/.dotfiles-private

# Add binaries into the path.
PATH=${DOTFILES}/bin:${PATH}

# Private dotfiles have precedence over public ones.
if [ -n "$DOTFILES_PRIV" ]; then
  PATH=${DOTFILES_PRIV}/bin:${PATH}
fi

export PATH

# Source all files in "source".
function src() {
  local file
  if [[ "$1" ]]; then
    source "$DOTFILES/source/$1.sh"
    if [ -n "$DOTFILES_PRIV" ]; then
      source "$DOTFILES_PRIV/source/$1.sh" >/dev/null 2>&1
    fi
  else
    for file in ${DOTFILES}/source/*; do
      source "$file"
    done
    if [ -n "$DOTFILES_PRIV" ]; then
      for file in ${DOTFILES_PRIV}/source/*; do
        source "$file" >/dev/null 2>&1
      done
    fi
  fi
}

# Run dotfiles script, then source.
function dotfiles() {
  $DOTFILES/bin/dotfiles "$@" && src
}

src
