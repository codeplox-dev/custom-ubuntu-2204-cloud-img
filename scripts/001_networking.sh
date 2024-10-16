#!/bin/sh -eux

# Disable Predictable Network Interface names and use eth0
[ -e /etc/network/interfaces ] && sed -i 's/en[[:alnum:]]*/eth0/g' /etc/network/interfaces;
sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0 \1"/g' /etc/default/grub;
update-grub;
sleep 20
