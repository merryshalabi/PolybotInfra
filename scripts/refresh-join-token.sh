#!/bin/bash
set -e

REGION="eu-west-2"
SSM_PARAM_NAME="/k8s/worker-join-command"

CONTROL_PLANE_IP="$1"

JOIN_CMD=$(kubeadm token create --ttl 24h --print-join-command --control-plane-endpoint "$CONTROL_PLANE_IP:6443")

aws ssm put-parameter \
  --name "$SSM_PARAM_NAME" \
  --type "SecureString" \
  --value "$JOIN_CMD" \
  --overwrite \
  --region "$REGION"
