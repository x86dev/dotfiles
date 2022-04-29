#!/bin/sh

sudo apt-get install -y --no-install-recommends yasm git subversion meld

# Install GEF (GDB Enhanced Features -- https://github.com/hugsy/gef). Requires Python 3.
wget -O ~/.gdbinit-gef.py -q https://gef.blah.cat/py
pip install capstone keystone unicorn

# Install KDE devel script for GDB. Includes some nice Qt printing stuff ("qs", ++).
wget -O ~/.gdbinit-kde-devel-gdb -q https://raw.githubusercontent.com/KDE/kde-dev-scripts/master/kde-devel-gdb
