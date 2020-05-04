
if [[ "$(which code)" ]]; then
  EDITOR="code --wait"
  VISUAL="code --wait --new-window"
  unset GIT_EDITOR
fi
