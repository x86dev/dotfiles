# Must be written using only portable Bourne shell syntax and commands.
# Leave shell specific customization to appropriate rc files.
# Where possible we try to use only commands we also have in emergency
# situations, like when in single user mode when nothing but the root
# file system is mounted, i.e. restrict to commands in /bin, /sbin or
# similar directories on the root file system.

# .profile is sourced at login by sh, ksh and bash. The zsh sources .zshrc.
# To get the same behaviour from zsh as well I did "cd; ln .profile .zshrc"
echo "File : ~${LOGNAME}/.profile"   # Tell the world who is responsible
echo "Host : $MY_HOST"
echo "OS   : $MY_OS"
echo "Shell: $MY_SHELL"

# Set umask
umask u=rwx,g=rx,o=rx

# Set the sequence of initialization:
# functions is first so that functions are usable by other dot files;
# functions, envars and aliases should not produce any output. Commands
# producing output should be executed in rc files.
# Does this shell support aliases? (Historic /bin/sh does not.)
if alias >/dev/null 2>&1; then
	_SETUP="functions envars aliases rc"
else
	_SETUP="functions envars rc"
fi

# Tweak options which are needed in order to get the stuff executed below.
case "${MY_SHELL}" in
	zsh)
		setopt shwordsplit
		;;
	*)
		;;
esac

_PRINT=echo
for _CUR_SETUP in ${_SETUP}; do
	${_PRINT} "Setting up ${_CUR_SETUP}:"
	if test -r ${HOME}/.${_CUR_SETUP}; then
		${_PRINT} "  universal"
		. ${HOME}/.${_CUR_SETUP}
	fi
	for _WHAT in  \
		${MY_OS}    \
		${MY_HOST}  \
		${MY_SHELL} \
		${MY_OS}.${MY_HOST}    \
		${MY_OS}.${MY_SHELL}   \
		${MY_HOST}.${MY_SHELL} \
		${MY_OS}.${MY_HOST}.${MY_SHELL} \
		${MY_HOST}.work \
		${MY_OS}.work \
		${MY_OS}.${MY_HOST}.work \
		; do
		if test -r ${HOME}/.${_CUR_SETUP}.${_WHAT}; then
			${_PRINT} "  ${_WHAT} specific"
			. ${HOME}/.${_CUR_SETUP}.${_WHAT}
		fi
	done
done

unset _CUR_SETUP _SETUP _WHAT _PRINT
: # Force a true exit status.
