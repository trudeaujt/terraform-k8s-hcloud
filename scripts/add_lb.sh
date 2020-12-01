#!/usr/bin/bash

echo "Load balancer ID: $LB_ID"
echo "Server ID: $SERVER_ID"

curl -X POST \
	-H "Authorization: Bearer $KUBE_TOKEN" \
	-H "Content-Type: application/json" \
	-d "{\"type\":\"server\",\"server\":{\"id\":$SERVER_ID}}" \
	"https://api.hetzner.cloud/v1/load_balancers/$LB_ID/actions/add_target"
