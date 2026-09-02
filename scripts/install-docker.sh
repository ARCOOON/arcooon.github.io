#!/usr/bin/env bash

# Root check
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: run as root (sudo $0)" >&2
  exit 1
fi

USER="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"

echo "[+] Installing dependencies (curl, uidmap)..."
# Updating packages and installing dependencies
DEBIAN_FRONTEND=noninteractive apt-get -q update
DEBIAN_FRONTEND=noninteractive apt-get -yq install curl uidmap

if command -v docker &> /dev/null; then
  echo "[#] Docker already installed, skipping the installer..."
else
  # Installing docker engine
  curl -fsSL https://get.docker.com | sh
fi

echo "[+] Configuring docker to run rootless"
# Run docker daemon in rootless mode
sudo -u "$USER" dockerd-rootless-setuptool.sh install

echo "[+] Applying docker host and env variables to ~/.bashrc"
# Applying docker host and path variables
sudo -u "$USER" echo 'export PATH=/usr/bin:$PATH' >> ~/.bashrc
sudo -u "$USER" echo 'export DOCKER_HOST=unix:///run/user/1000/docker.sock' >> ~/.bashrc

echo "[+] Starting docker service"
# Start system docker service
sudo -u "$USER" systemctl --user start docker.service
