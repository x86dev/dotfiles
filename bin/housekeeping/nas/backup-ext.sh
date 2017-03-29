#!/bin/sh
# Note: Package 'rsync' must be installed.

if [ $# -lt 1 ]; then
    echo "Must specify source root!"
    echo "Usage: $0 </media/XXX>"
    exit
fi

MY_ROOT="$1"
MY_DIRS="${MY_ROOT}/audiobooks \
         ${MY_ROOT}/com \
         ${MY_ROOT}/ebooks \
         ${MY_ROOT}/iso \
         ${MY_ROOT}/learning \
         ${MY_ROOT}/mags \       
         ${MY_ROOT}/music"

rsync -aAXv --progress ${MY_DIRS} /media/backup_ext
