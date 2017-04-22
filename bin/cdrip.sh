#!/bin/sh
FILE_LOG=/tmp/cdrip.log
FILE_PID=/tmp/cdrip.lock

if [ -f ${FILE_PID} ]; then
    echo "Already running ..."
    exit 1
fi

echo "== Started: $(date)" >> ${FILE_LOG}

touch ${FILE_PID}
abcde -c $HOME/.dotfiles/bin/cdrip-abcde.conf 2>&1 >> ${FILE_LOG}
rc=$?
echo "== Ended: $(date) with exit code $rc" >> ${FILE_LOG}

if [ $rc != 0 ]; then
    eject
fi

rm ${FILE_PID}
exit $rc

# /etc/udev/rules.d/99-cdrip.rules:
# SUBSYSTEM=="block", KERNEL=="sr0", ACTION=="change", RUN+="sudo $HOME/.dotfiles/bin/cdrip.sh &"
# sudo udevadm control --reload
