#!/bin/sh
umount /media/backup_ext
cryptsetup luksClose backup_ext_enc
