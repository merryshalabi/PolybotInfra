#!/bin/bash
set -e

REGION="eu-west-2"
SSM_PARAM_NAME="/k8s/worker-join-command"

CONTROL_PLANE_IP="$1"

JOIN_COMMAND=$(kubeadm token create --print-join-command)

aws ssm put-parameter \
  --name "$SSM_PARAM_NAME" \
  --value "$JOIN_COMMAND" \
  --type "SecureString" \
  --overwrite \
  --region eu-west-2