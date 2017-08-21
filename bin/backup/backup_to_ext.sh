#!/bin/sh

set -e

if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Aborting."
    exit 1
fi

MY_SRC_ROOT=/media/8591bae9-0447-4630-acbb-8f639fa9c811
MY_SRC_DIRS="${MY_SRC_ROOT}/com \
             ${MY_SRC_ROOT}/ebooks \
             ${MY_SRC_ROOT}/mags \
             ${MY_SRC_ROOT}/pictures \
             ${MY_SRC_ROOT}/audiobooks \
             ${MY_SRC_ROOT}/music \
             ${MY_SRC_ROOT}/learning \
             ${MY_SRC_ROOT}/iso"
MY_DST_PARTITION=/dev/sdd1

umount /media/backup_ext > /dev/null 2>&1 || /bin/true
mkdir -p /media/backup_ext
cryptsetup luksOpen ${MY_DST_PARTITION} backup_ext
mount /dev/mapper/backup_ext /media/backup_ext

rsync -aAX --progress ${MY_SRC_DIRS} /media/backup_ext

umount /media/backup_ext
cryptsetup luksClose backup_ext
