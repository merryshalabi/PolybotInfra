#!/bin/bash
set -e

REGION="eu-west-2"
SSM_PARAM_NAME="/k8s/worker-join-command"

# Export kubeconfig so kubeadm can work
export KUBECONFIG=/etc/kubernetes/admin.conf

# Generate new join command
JOIN_COMMAND=$(sudo kubeadm token create --print-join-command)

# Push to SSM
aws ssm put-parameter \
  --name "$SSM_PARAM_NAME" \
  --value "$JOIN_COMMAND" \
  --type "SecureString" \
  --overwrite \
  --region "$REGION"
