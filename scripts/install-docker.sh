#!/usr/bin/env bash

# Checking root access
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root!"
  exit
fi

# Updating packages
apt update
apt install curl -y

# Installing docker engine
curl -fsSL https://get.docker.com | sh
