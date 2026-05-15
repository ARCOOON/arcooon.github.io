#!/usr/bin/env bash

apt update
apt upgrade -y
wget https://go.dev/dl/go1.26.3.linux-amd64.tar.gz

sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.26.3.linux-amd64.tar.gz

echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

echo '==== GoLang ===='
go version
echo '================'
