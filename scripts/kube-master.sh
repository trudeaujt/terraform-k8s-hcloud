#!/usr/bin/bash
set -eu

if (($MASTER_INDEX == 0)); then
  echo "Skip"
else
  echo "Join to Cluster"
  eval "$(cat /tmp/kubeadm_control_plane_join)"
  systemctl enable docker kubelet
fi
