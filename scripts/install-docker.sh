#!/usr/bin/env bash

# Root check
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: run as root (sudo $0)" >&2
  exit 1
fi

# Updating packages
apt update
apt install curl -y

# Installing docker engine
curl -fsSL https://get.docker.com | sh
