#!/bin/sh
# Note: Package 'rsync' must be installed.

if [ $# -lt 1 ]; then
    echo "Must specify source root!"
    echo "Usage: $0 </path/to/media/root>"
    exit
fi

MY_ROOT="$1"
MY_DIRS="${MY_ROOT}/audiobooks \
         ${MY_ROOT}/ebooks \
         ${MY_ROOT}/iso \
         ${MY_ROOT}/incoming \
         ${MY_ROOT}/learning \
         ${MY_ROOT}/mags \
         ${MY_ROOT}/music \
         ${MY_ROOT}/pictures \
         ${MY_ROOT}/srv/photoprism"
MY_TARGET=/media/backup_ext

rsync -aAX --progress --stats ${MY_DIRS} ${MY_TARGET} --log-file ${MY_TARGET}/rsync_last_run.log
