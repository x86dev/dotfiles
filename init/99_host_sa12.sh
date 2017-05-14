# Ubuntu-only stuff. Abort if not Ubuntu.
is_ubuntu || return 1

MY_POWER_FILE=/etc/pm/power.d/sa12

sudo cat > ${MY_POWER_FILE} << EOF
#!/bin/sh
# Enable HDA codec power management.
echo 'auto' > '/sys/class/sound/controlC0/device/power/control';
# Autosuspend for USB device ACER Hawaii Keyboard [Chicony].
echo 'auto' > '/sys/bus/usb/devices/1-4/power/control';
EOF

sudo chmod +x ${MY_POWER_FILE}
