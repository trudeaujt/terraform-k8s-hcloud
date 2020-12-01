#!/bin/bash
set -eu
SSH_PRIVATE_KEY=${SSH_PRIVATE_KEY:-}
SSH_USERNAME=${SSH_USERNAME:-}
SSH_HOST=${SSH_HOST:-}

ID=${ID:-}
TARGET=${TARGET:-}

mkdir -p "${TARGET}"

scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i "${SSH_PRIVATE_KEY}" \
    "${SSH_USERNAME}@${SSH_HOST}:/tmp/kubeadm_join_${ID}" \
    "${TARGET}"
