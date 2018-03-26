#!/bin/bash

source ${HOME}/.dotfiles/link/.functions
handbrake_transcode_file "$1" 2>&1 | tee /tmp/trancode.log
