# dotfiles
Yum yum, dotfiles! For *NIX-OSes only.

**Important: Make sure to check the source files instead of blindly using this repository!**


### Git-free install

To install these dotfiles without Git:

```bash
bash -c "$(curl -fsSL https://raw.github.com/x86dev/dotfiles/master/bin/dotfiles)" && source ~/.bashrc
```

### Install using Git

```bash
cd; git clone --recursive https://github.com/x86dev/dotfiles.git .dotfiles && source ~/.dotfiles/bin/dotfiles
```

### Update

To update, just do:

```bash
dotfiles
```

### Credits

This is a customized fork of [Ben Alman's](https://github.com/cowboy/dotfiles) excellent dotfiles.
Take a look at Ben's [README.md](https://github.com/cowboy/dotfiles/blob/master/README.md) -- there you also will find an extensive user guide about how all this stuff works.
