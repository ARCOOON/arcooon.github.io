#!/bin/bash
apt update
apt install curl -y
curl -fsSL https://tailscale.com/install.sh | sh
