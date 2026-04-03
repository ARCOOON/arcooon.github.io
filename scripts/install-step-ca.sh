#!/usr/bin/env bash

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: run as root (sudo $0)" >&2
  exit 1
fi

apt-get update
apt-get install -y --no-install-recommends curl gpg ca-certificates

curl -fsSL https://packages.smallstep.com/keys/apt/repo-signing-key.gpg -o /etc/apt/keyrings/smallstep.asc

cat << EOF > /etc/apt/sources.list.d/smallstep.sources
Types: deb
URIs: https://packages.smallstep.com/stable/debian
Suites: debs
Components: main
Signed-By: /etc/apt/keyrings/smallstep.asc
EOF

apt-get update
apt-get -y install step-cli step-ca
