setopt shwordsplit

# Command completion for tldr
[ -f "$MY_LOCAL_BIN/tldr" ] && compctl -k "($( tldr 2>/dev/null --list))" tldr
