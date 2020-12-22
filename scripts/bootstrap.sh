#!/bin/bash
set -eu
SSH_PORT=${SSH_PORT:-}

echo "Port $SSH_PORT" > /etc/ssh/sshd_config.d/port.conf
systemctl restart sshd

waitforapt(){
  while fuser /var/lib/apt/lists/lock >/dev/null 2>&1 ; do
     echo "Waiting for other software managers to finish..." 
     sleep 1
  done
}

apt-get -qq update
#apt-get -qq upgrade -y
apt-get -qq install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common