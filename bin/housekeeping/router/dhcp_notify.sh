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
#   $1 = add | old | test
#   $2 = mac address
#   $3 = ip address
#   $4 = device name

# Needs ${MY_NMAP_BIN} installed (with script support).
# On OpenWRT, this would be "nmap-full" (needs quite a bit of space).

CUR_PATH=$(readlink -f $0 | xargs dirname)

if [ "$1" != "test" ]; then
    MY_CFG_FILE=${CUR_PATH}/dhcp_notify.conf
    if [ -f "$MY_CFG_FILE" ]; then
        . ${MY_CFG_FILE}
    else
        echo "Error: Config file \"$MY_CFG_FILE\" does not exist. Exiting."
        exit 1
    fi

    if [   -z "$MY_MAIL_USER" \
        -o -z "$MY_MAIL_PASSWORD" \
        -o -z "$MY_MAIL_ADDR" \
        -o -z "$MY_MAIL_SMTP_ADDR" ]; then
        echo "Error: Mail credentials not set or invalid. Exiting."
        exit 1
    fi
fi

if [ "$1" = "test" ]; then
    MY_MAC_LIST=${CUR_PATH}/known_mac_addr
    MY_LOG_PATH=${CUR_PATH}
    MY_HOST_HOSTNAME=test_hostname
    MY_HOST_DOMAIN=test_domain
else
    MY_MAC_LIST="/etc/known_mac_addr"
    MY_LOG_PATH="/www/dhcp"
    MY_HOST_HOSTNAME=$(uci get system.@system[0].hostname)
    MY_HOST_DOMAIN=$(uci get dhcp.@dnsmasq[0].domain)
fi

if [ -z "$MY_HOST_HOSTNAME" ]; then
    MY_HOST_HOSTNAME="<Unknown>"
fi
MY_HOST_MAC=$2
MY_HOST_IP=$3
MY_HOST_DEVNAME=$4

MY_LOG_FILE="$MY_LOG_PATH/index.html"
MY_MAIL_BODY_FILE="/tmp/dhcp_notify_mail_body.txt"
MY_NMAP_LOG_FILE="/tmp/dhcp_notify_nmap.txt"

log()
{
    echo "[`date`] $1<br>" | tee -a ${MY_LOG_FILE}
}

log_nmap()
{
    echo "$1" >> "$MY_NMAP_LOG_FILE"
}

log_mail()
{
    echo "$1" >> "$MY_MAIL_BODY_FILE"
}

nmap_scan_host()
{
    # A bit of nmap banging.
    # On OpenWRT routers there are two versions; so try the full-blown one first.
    MY_NMAP_BIN=$(which nmap-full)
    if [ ! -x "$MY_NMAP_BIN" ]; then
        MY_NMAP_BIN=$(which nmap)
    fi
    if [ -x "$MY_NMAP_BIN" ]; then
        MY_NMAP_COMMON_OPTS="--append-output -oN ${MY_NMAP_LOG_FILE} $1"
        log_nmap "Ping scan ..."
        ${MY_NMAP_BIN} -sp ${MY_NMAP_COMMON_OPTS}
        log_nmap "Scanning top 50 ports ..."
        ${MY_NMAP_BIN} --top-ports 50 --reason ${MY_NMAP_COMMON_OPTS}
        log_nmap "Trying to detect OS ..."
        ${MY_NMAP_BIN} -T4 -A ${MY_NMAP_COMMON_OPTS}
        log_nmap "Trying to detect service/daemon versions ..."
        ${MY_NMAP_BIN} -sV --version-intensity 5 --reason ${MY_NMAP_COMMON_OPTS}
        log_nmap "Performing IP protocol scan ..."
        ${MY_NMAP_BIN} -sO --reason ${MY_NMAP_COMMON_OPTS}
        log_nmap "Performing stealth sync scan ..."
        ${MY_NMAP_BIN} -sS -v ${MY_NMAP_COMMON_OPTS}
        log_nmap "Scanning UDP ports ..."
        ${MY_NMAP_BIN} -sU -v  --reason ${MY_NMAP_COMMON_OPTS}
        log_nmap "Scanning SMB shares ..."
        ${MY_NMAP_BIN} --script smb-enum-shares.nse -p445 ${MY_NMAP_COMMON_OPTS}
        ${MY_NMAP_BIN} -sU -sS --script smb-enum-shares.nse -p U:137,T:139 ${MY_NMAP_COMMON_OPTS}
        log_nmap "Scanning NFS exports ..."
        ${MY_NMAP_BIN} -sV --script=nfs-showmount ${MY_NMAP_COMMON_OPTS}
        log_nmap "Scanning UPnP info ..."
        ${MY_NMAP_BIN} -sU -p 1900 --script=upnp-info ${MY_NMAP_COMMON_OPTS}
    else
        log_nmap "WARNING: No nmap / nmap-full installed! No further host information available."
    fi
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

if ([ "$1" = "add" ] || [ "$1" = "test" ]) && [ "$MY_UNKNOWN_MAC_ADDR" -ne 0 ]; then

    nmap_scan_host "$MY_HOST_IP"

    if [ -n "$MY_MAIL_ADDR" ]; then
        MY_MAIL_SMTP_OPTS="-smtp $MY_MAIL_SMTP_ADDR -starttls -port $MY_MAIL_SMTP_PORT -auth"
        MY_MAIL_SUB="New device: $MY_HOST_HOSTNAME@$MY_HOST_DOMAIN: $MY_HOST_IP ($MY_HOST_DEVNAME - $MY_HOST_MAC)"
        log_mail "A new device just connected: $MY_HOST_HOSTNAME@$MY_HOST_DOMAIN, IP:$MY_HOST_IP, MAC:$MY_HOST_MAC, Name:$MY_HOST_DEVNAME"
        cat "$MY_NMAP_LOG_FILE" >> "$MY_MAIL_BODY_FILE"
        mailsend -f ${MY_MAIL_USER} -t ${MY_MAIL_ADDR} -user "$MY_MAIL_USER" -pass "$MY_MAIL_PASSWORD" ${MY_MAIL_SMTP_OPTS} -sub "$MY_MAIL_SUB" -msg-body ${MY_MAIL_BODY_FILE}
        if [ "$1" != "test" ]; then
            rm ${MY_MAIL_BODY_FILE}
        fi
    fi

    log "New device connected: $MY_HOST_HOSTNAME@$MY_HOST_DOMAIN: $MY_HOST_IP ($MY_HOST_DEVNAME - $MY_HOST_MAC)"

    # Put MAC into MAC list.
    echo "$MY_HOST_MAC;$MY_HOST_DEVNAME" >> ${MY_MAC_LIST}
fi

if [ "$1" = "old" ]; then
    log "Already known device reconnected: $MY_HOST_HOSTNAME@$MY_HOST_DOMAIN: $MY_HOST_IP ($MY_HOST_DEVNAME - $MY_HOST_MAC)"
fi
