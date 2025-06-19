#!/bin/bash
apt update
apt install curl -y
curl -fsSL https://tailscale.com/install.sh | sh

cat <<EOF
Add the following to /etc/pve/lxc/1xx.conf inside your pve shell.

lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
EOF
