#!/bin/sh

# Copyright 2016-2018 by Andreas Loeffler (x86dev).
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

#
# Simple script to perform a Wake-on-LAN (WOL) request for a given server.
# As most switches / routers do the routing internally without reaching iptable's / netfilter's
# filtering routines, the server to wake up must be in a different (V)LAN.
#
# Examples for iptables rules:
#   iptables -I FORWARD 1 -p tcp -d 192.168.1.120 -m multiport --dports 21,22,80,443,137,138,139,6789,8096,8920 -m limit --limit 30/min -j LOG --log-level 7 --log-prefix '<NAS WOL> '
#   iptables -I FORWARD 1 -m state -p tcp -d 192.168.1.120 --dport 8920 -m limit --limit 30/min -j LOG --log-level 7 --log-prefix '<NAS WOW> '
#
# This script then periodically checks - based on the NAS filtering + logging rules - the dmesg
# log to see if we need to perform a WOL request.
#
# Tested on OpenWrt 15.05 on a Netgear WNDR3700 + WNDR4000.
#
# Note: The script requires the tool 'etherwake' installed to perform the actual WOL request.
#       Everything else should come out-of-the-box.
#

CUR_PATH=$(readlink -f $0 | xargs dirname)
CUR_EXITCODE=0

CFG_FILE=${CUR_PATH}/wol-dmesg.conf

if [ -f "$CFG_FILE" ]; then
    . ${CFG_FILE}
else
    echo "Error: Config file '$CFG_FILE' does not exist. Exiting."
    exit 1
fi

PING_RETRIES=1

LOG_PATH="/www/wol"
LOG_FILE="$LOG_PATH/index.html"
LOG_TOKEN="<NAS WOL>"
LOG_DEBUG=0

SLEEP_SEC_ALIVE=30
SLEEP_SEC_CHECK=5

WOL=/usr/bin/etherwake
WOL_OPTS="-i $WOL_INTERFACE"

log()
{
    echo "[`date`] $1<br>" | tee -a ${LOG_FILE}
}

log_debug()
{
    if ["$LOG_DEBUG" = "1" ]; then
        echo "[`date`] $1<br>" | tee -a ${LOG_FILE}
    fi
}

# Clear the dmesg log before we begin.
dmesg -c 2>&1 > /dev/null

# Make sure that the log path exists.
mkdir -p "$LOG_PATH"

log "\"<meta http-equiv=\"refresh\" content=\"5\">"
log "Script started"
log "Using config: $CFG_FILE"

LOG_MSG_ID_OLD=""

while true; do

    LOG_DMESG=$(dmesg | grep "$LOG_TOKEN" | tail -n1)
    LOG_MSG_ID_NEW=$(echo $LOG_DMESG | sed -n 's/.*ID=\([0-9]*\).*/\1/p')
    LOG_SRC_IP=$(echo $LOG_DMESG | sed -n 's/.*SRC=\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
    if [ -n "$LOG_SRC_IP" ]; then
        LOG_SRC_NAME=$(nslookup $LOG_SRC_IP | sed -n 's/.*arpa.*name = \(.*\)/\1/p')
    fi
    LOG_DST_PORT=$(echo $LOG_DMESG | sed -n 's/.*DPT=\([0-9]*\).*/\1/p')

    if [ "$LOG_MSG_ID_NEW" != "" -a "$LOG_MSG_ID_NEW" != "$LOG_MSG_ID_OLD" ]; then
        if ping -qc ${PING_RETRIES} ${TARGET_IP} 2>&1 > /dev/null; then
            log_debug "Accessed by $LOG_SRC_NAME ($LOG_SRC_IP) (port $LOG_DST_PORT) and is already alive" 
        else
            log "$LOG_SRC_NAME ($LOG_SRC_IP) causes wake on lan (port $LOG_DST_PORT)"
            ${WOL} ${WOL_OPTS} ${TARGET_MAC} 2>&1 > /dev/null
       fi
       LOG_MSG_ID_OLD=${LOG_MSG_ID_NEW}
       log_debug "Sleeping for $SLEEP_SEC_ALIVE seconds ..."
       sleep ${SLEEP_SEC_ALIVE}
       dmesg -c 2>&1 > /dev/null
    fi
    sleep ${SLEEP_SEC_CHECK}
done

exit 0
