#!/usr/bin/bash
set -eu

echo "Master index: $MASTER_INDEX"
echo "Load balancer IP: $LB_IP"

if (( $MASTER_INDEX == 0 ))
then
    echo "Initialize Cluster"
    if [[ -n "$FEATURE_GATES" ]]
    then
      kubeadm init --control-plane-endpoint="$LB_IP:6443" --pod-network-cidr=10.244.0.0/16 --upload-certs --feature-gates "$FEATURE_GATES"
    else
      kubeadm init --control-plane-endpoint="$LB_IP:6443" --pod-network-cidr=10.244.0.0/16 --upload-certs
    fi

    # used to join nodes to the cluster
    kubeadm token create --print-join-command > /tmp/kubeadm_join

    kubeadm init phase upload-certs --upload-certs > /tmp/cert.key
    export CERT_KEY="$(tail -1 /tmp/cert.key)"
    kubeadm token create --print-join-command --certificate-key $CERT_KEY > /tmp/kubeadm_control_plane_join

    mkdir -p "$HOME/.kube"
    cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
else
    echo "Join to Cluster"
    eval "$(cat /tmp/kubeadm_control_plane_join)"
fi

systemctl enable docker kubelet
