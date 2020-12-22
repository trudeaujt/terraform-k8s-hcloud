#!/bin/bash
set -eu
SSH_PRIVATE_KEY=${SSH_PRIVATE_KEY:-}
SSH_USERNAME=${SSH_USERNAME:-}
SSH_HOST=${SSH_HOST:-}
SSH_PORT=${SSH_PORT:-}

ID=${ID:-}
TARGET=${TARGET:-}

mkdir -p "${TARGET}"

scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i "${SSH_PRIVATE_KEY}" \
    -P "${SSH_PORT}" \
    "${SSH_USERNAME}@${SSH_HOST}:/tmp/kubeadm_join_${ID}" \
    "${TARGET}"
