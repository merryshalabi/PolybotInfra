#!/bin/bash
set -e

# Automatically discover control plane IP by Name tag
CONTROL_PLANE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=control-plane" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text \
  --region eu-west-2)

echo "🔍 Discovered control-plane IP: $CONTROL_PLANE_IP"
echo "📦 Starting control-plane initialization..."

# Run the initialization commands on the remote EC2 via SSH
ssh -o StrictHostKeyChecking=no -i ~/.ssh/merryPolybotKey.pem ubuntu@$CONTROL_PLANE_IP << 'EOF'
  set -e

  if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo "🔧 Initializing Kubernetes cluster..."
    sudo kubeadm init --pod-network-cidr=192.168.0.0/16 | tee /tmp/kubeadm-init.log
  fi

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  echo "⏳ Waiting for Kubernetes API server to be ready..."
  for i in {1..30}; do
    if kubectl get nodes &> /dev/null; then
      echo "✅ API server is up."
      break
    else
      echo "Waiting for API server... ($i/30)"
      sleep 5
    fi
  done

  if ! kubectl get pods -n kube-system | grep -q calico; then
    echo "📡 Installing Calico CNI..."
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
  fi

  JOIN_COMMAND=$(kubeadm token create --print-join-command)
  aws ssm put-parameter \
    --name "/k8s/worker-join-command" \
    --type "SecureString" \
    --value "$JOIN_COMMAND" \
    --overwrite \
    --region eu-west-2
EOF

echo "✅ Control plane initialized and join command saved to SSM."
