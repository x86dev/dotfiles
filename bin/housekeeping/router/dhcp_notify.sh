#!/bin/sh

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

# Script to detect, log and get notified of new DHCP leases.

# This will be called by dnsmasq everytime a new device is connected
# with the following arguments:
#   $1 = add | old
#   $2 = mac address
#   $3 = ip address
#   $4 = device name

CUR_PATH=$(readlink -f $0 | xargs dirname)

# Enable this to test the script locally.
#MY_TEST=1

MY_CFG_FILE=${CUR_PATH}/dhcp_notify.conf

if [ -f "$MY_CFG_FILE" ]; then
    . ${MY_CFG_FILE}
else
    echo "Error: Config file \"$MY_CFG_FILE\" does not exist. Exiting."
    exit 1
fi

if [    -z "$MY_MAIL_USER" \
     -o -z "$MY_MAIL_PASSWORD" \
     -o -z "$MY_MAIL_ADDR" \
     -o -z "$MY_MAIL_SMTP_ADDR" ]; then
    echo "Error: Mail credentials not set or invalid. Exiting."
    exit 1
fi

if [ -z "$MY_TEST" ]; then
    MY_MAC_LIST="/etc/known_mac_addr"
    MY_LOG_PATH="/www/dhcp"
    MY_HOST_HOSTNAME=$(uci get system.@system[0].hostname)
    MY_HOST_DOMAIN=$(uci get dhcp.@dnsmasq[0].domain)
else
    MY_MAC_LIST=${CUR_PATH}/known_mac_addr
    MY_LOG_PATH=${CUR_PATH}
    MY_HOST_HOSTNAME=test_hostname
    MY_HOST_DOMAIN=test_domain
fi

if [ -z "$MY_HOST_HOSTNAME" ]; then
    MY_HOST_HOSTNAME="<Unknown>"
fi
MY_HOST_MAC=$2
MY_HOST_IP=$3
MY_HOST_DEVNAME=$4

MY_LOG_FILE="$MY_LOG_PATH/index.html"

log()
{
    echo "[`date`] $1<br>" | tee -a ${MY_LOG_FILE}
}

# Make sure the known MAC list exists.
touch "$MY_MAC_LIST"

# Make sure that the log path exists.
mkdir -p "$MY_LOG_PATH"

# Make sure the log file exists.
touch "$MY_LOG_FILE"

# Check if the MAC is in known devices list and extract the existing device name from it.
MY_HOST_DEVNAME_RESOLVED=$(awk -F ";" "BEGIN { rc=1 } \$1 == \"$MY_HOST_MAC\" { print \$2; rc=0 } END { exit rc }" "$MY_MAC_LIST") 2>&1 > /dev/null
MY_UNKNOWN_MAC_ADDR=$?

if [ -n "$MY_HOST_DEVNAME_RESOLVED" ]; then
    MY_HOST_DEVNAME=${MY_HOST_DEVNAME_RESOLVED}
fi

if [ "$1" = "add" ] && [ "$MY_UNKNOWN_MAC_ADDR" -ne 0 ]; then

    MY_MAIL_SMTP_OPTS="-smtp $MY_MAIL_SMTP_ADDR -starttls -port $MY_MAIL_SMTP_PORT -auth"

    MY_MAIL_SUB="New device: $MY_HOST_HOSTNAME@$MY_HOST_DOMAIN: $MY_HOST_IP ($MY_HOST_DEVNAME - $MY_HOST_MAC)"
    MY_MAIL_BODY_FILE="/tmp/mailsend_body.txt"
    echo "A new device just connected: $MY_HOST_HOSTNAME@$MY_HOST_DOMAIN, IP:$MY_HOST_IP, MAC:$MY_HOST_MAC, Name:$MY_HOST_DEVNAME" > ${MY_MAIL_BODY_FILE}

    # A bit of nmap banging.
    MY_NMAP_LOG_FILE="/tmp/nmap_log.txt"
    MY_NMAP_COMMON_OPTS="--append-output -oN $MY_NMAP_LOG_FILE $MY_HOST_IP"
    nmap -T4 -A ${MY_NMAP_COMMON_OPTS}
    nmap -sV --version-intensity 5 ${MY_NMAP_COMMON_OPTS}
    nmap -sO ${MY_NMAP_COMMON_OPTS}
    nmap -sS ${MY_NMAP_COMMON_OPTS}
    nmap -sU ${MY_NMAP_COMMON_OPTS}
    cat "$MY_NMAP_LOG_FILE" >> "$MY_MAIL_BODY_FILE"
    rm "$MY_NMAP_LOG_FILE"

    mailsend -f ${MY_MAIL_USER} -t ${MY_MAIL_ADDR} -user "$MY_MAIL_USER" -pass "$MY_MAIL_PASSWORD" ${MY_MAIL_SMTP_OPTS} -sub "$MY_MAIL_SUB" -msg-body ${MY_MAIL_BODY_FILE}
    rm ${MY_MAIL_BODY_FILE}

    log "New device connected: $MY_HOST_HOSTNAME@$MY_HOST_DOMAIN: $MY_HOST_IP ($MY_HOST_DEVNAME - $MY_HOST_MAC)"

    # Put MAC into MAC list.
    echo "$MY_HOST_MAC;$MY_HOST_DEVNAME" >> ${MY_MAC_LIST}
fi

if [ "$1" = "old" ]; then
    log "Already known device reconnected: $MY_HOST_HOSTNAME@$MY_HOST_DOMAIN: $MY_HOST_IP ($MY_HOST_DEVNAME - $MY_HOST_MAC)"
fi
