#!/usr/bin/env bash

# Root check
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: run as root (sudo $0)" >&2
  exit 1
fi

# Updating packages and installing dependencies
apt update
apt install curl uidmap -y

# Installing docker engine
curl -fsSL https://get.docker.com | sh

# Run docker daemon in rootless mode
dockerd-rootless-setuptool.sh install
