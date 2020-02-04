#!/bin/sh

# script to detect new dhcp lease

# this will be called by dnsmasq everytime a new device is connected
# with the following arguments
# $1 = add | old
# $2 = mac address
# $3 = ip address
# $4 = device name

source /root/mail_creds.txt

known_mac_addr="/etc/known_mac_addr"

MY_HOST_HOSTNAME=$(uci get system.@system[0].hostname)
if [ -z "$MY_HOST_HOSTNAME" ]; then
    MY_HOST_HOSTNAME="<Unknown>"
fi
MY_HOST_DOMAIN=$(uci get dhcp.@dnsmasq[0].domain)
MY_HOST_MAC=$2
MY_HOST_IP=$3
MY_HOST_DEVNAME=$4

# check if the mac is in known devices list
grep -q "$MY_HOST_MAC" "$known_mac_addr"
unknown_mac_addr=$?

if [ "$1" == "add" ] && [ "$unknown_mac_addr" -ne 0 ]; then
    
    MY_MAIL_SMTP_OPTS="-smtp $MY_MAIL_SMTP_ADDR -ssl -port 465 -auth"

    MY_MAIL_SUB="New device: $MY_HOST_HOSTNAME@$MY_HOST_DOMAIN: $MY_HOST_IP ($MY_HOST_DEVNAME - $MY_HOST_MAC)"
    MY_MAIL_BODY_FILE="/tmp/mailsend_body.txt"
    echo "A new device just connected: $MY_HOST_HOSTNAME@$MY_HOST_DOMAIN, IP:$MY_HOST_IP, MAC:$MY_HOST_MAC, Name:$MY_HOST_DEVNAME" > ${MY_MAIL_BODY_FILE}

    echo `date` ${MY_MAIL_SUB} >> /tmp/dhcpmasq.log
    mailsend -f root@openwrt -t ${MY_MAIL_ADDR} -user "$MY_MAIL_USER" -pass "$MY_MAIL_PASSWORD" ${MY_MAIL_SMTP_OPTS} -sub "$MY_MAIL_SUB" -msg-body ${MY_MAIL_BODY_FILE}

    rm ${MY_MAIL_BODY_FILE}
fi
