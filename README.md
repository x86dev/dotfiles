# dotfiles
Yum yum, dotfiles! For *NIX-OSes only.


### Git-free install

To install these dotfiles without Git:

```bash
bash -c "$(curl -fsSL https://raw.github.com/x86dev/dotfiles/master/bin/dotfiles)" && source ~/.bashrc
```

### Using Git and the bootstrap script

You can clone the repository wherever you want. (I like to keep it in `~/Projects/dotfiles`, with `~/dotfiles` as a symlink.) The bootstrapper script will pull in the latest version and copy the files to your home folder.

```bash
git clone --recursive https://github.com/x86dev/dotfiles.git && cd dotfiles && source bootstrap.sh
```

To update, `cd` into your local `dotfiles` repository and then:

```bash
source bootstrap.sh
```

### Credits

This is a customized fork of [Ben Alman's](https://github.com/cowboy/dotfiles) excellent dotfiles.
