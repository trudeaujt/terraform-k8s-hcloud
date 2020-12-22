#!/usr/bin/bash
set -eu

echo "
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
networking:
  podSubnet: 10.244.0.0/16
controlPlaneEndpoint: "$LB_IP:6443"
controllerManagerExtraArgs:
  address: 0.0.0.0
schedulerExtraArgs:
  address: 0.0.0.0
controllerManager:
  extraArgs:
    bind-address: 0.0.0.0
scheduler:
  extraArgs:
    address: 0.0.0.0
    bind-address: 0.0.0.0
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
metricsBindAddress: 0.0.0.0:10249
" > /tmp/kubeadm.yml


echo "Initialize Cluster"
if [[ -n "$FEATURE_GATES" ]]; then
  kubeadm init --upload-certs --feature-gates "$FEATURE_GATES" --config /tmp/kubeadm.yml
else
  kubeadm init --upload-certs --config /tmp/kubeadm.yml
fi

# used to join nodes to the cluster
kubeadm token create --print-join-command >/tmp/kubeadm_join

kubeadm init phase upload-certs --upload-certs >/tmp/cert.key
export CERT_KEY="$(tail -1 /tmp/cert.key)"
kubeadm token create --print-join-command --certificate-key $CERT_KEY >/tmp/kubeadm_control_plane_join

mkdir -p "$HOME/.kube"
cp /etc/kubernetes/admin.conf "$HOME/.kube/config"

systemctl enable docker kubelet
