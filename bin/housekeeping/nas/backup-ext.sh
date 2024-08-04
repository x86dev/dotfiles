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
MY_MOUNT=/media/backup_ext

set -e

# Make sure that mount target exists.
cd ${MY_MOUNT}
MY_TARGET=${MY_MOUNT}/$(date +%Y%m%d)
mkdir -p ${MY_TARGET}
nohup rsync -aAX --progress --stats ${MY_DIRS} ${MY_TARGET} --log-file ${MY_TARGET}/rsync_last_run.log &
