#!/bin/sh
# Note: Package 'cryptsetup' must be installed.

## @todo Does not work on OS X -- flag "-f" does not exist there.
SCRIPT_PATH=$(readlink -f $0 | xargs dirname)
SCRIPT_EXITCODE=0

if [ $# -lt 1 ]; then
    echo "Must specify a device to mount!"
    echo "Usage: $0 </dev/sdXXX>"
    echo ""
    echo "Example: $0 /dev/sde"
    exit
fi

# Unmount first.
. ${SCRIPT_PATH}/backup-ext-umount.sh

# Mount.
cryptsetup luksOpen $1 backup_ext_enc
mkdir -p /media/backup_ext
mount /dev/mapper/backup_ext_enc /media/backup_ext
