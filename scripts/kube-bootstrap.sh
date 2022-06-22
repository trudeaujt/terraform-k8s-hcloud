#!/bin/bash
set -eu
DOCKER_VERSION=${DOCKER_VERSION:-}
KUBERNETES_VERSION=${KUBERNETES_VERSION:-}
MASTER_INDEX=${MASTER_INDEX:-}

waitforapt() {
  while fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
    echo "Waiting for other software managers to finish..."
    sleep 1
  done
}

if (($MASTER_INDEX == 0)); then
  echo "Skip"
else
#  echo "
#Package: docker-ce
#Pin: version ${DOCKER_VERSION}.*
#Pin-Priority: 1000
#" >/etc/apt/preferences.d/docker-ce
#  waitforapt
#  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
#  add-apt-repository \
#    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
#   $(lsb_release -cs) \
#   stable"
#  apt-get -qq update && apt-get -qq install -y docker-ce
#
#  cat >/etc/docker/daemon.json <<EOF
#{
#  "storage-driver":"overlay2" 
#}
#EOF
#
#  systemctl restart docker.service
  
  VERSION=1.24
  OS=xUbuntu_20.04
  echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
  echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list

  curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/Release.key | apt-key add -
  curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | apt-key add -

  apt-get update
  apt-get install cri-o cri-o-runc

  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

  echo "
Package: kubelet
Pin: version ${KUBERNETES_VERSION}-*
Pin-Priority: 1000
" >/etc/apt/preferences.d/kubelet

  echo "
Package: kubeadm
Pin: version ${KUBERNETES_VERSION}-*
Pin-Priority: 1000
" >/etc/apt/preferences.d/kubeadm

  waitforapt
  apt-get -qq update
  apt-get -qq install -y kubelet kubeadm

  mv -v /root/10-kubeadm.conf /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

  systemctl daemon-reload
  systemctl restart kubelet
fi
