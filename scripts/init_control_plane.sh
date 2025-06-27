#!/bin/bash
set -e

echo "📦 Starting control-plane initialization..."

# Only initialize if not already done
if [ ! -f /etc/kubernetes/admin.conf ]; then
  echo "🔧 Initializing Kubernetes cluster..."
  sudo kubeadm init --pod-network-cidr=192.168.0.0/16 | tee /tmp/kubeadm-init.log
fi

# Configure kubectl for current user (assumes running as ubuntu or ec2-user)
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Calico if not already installed
if ! kubectl get pods -n kube-system | grep -q calico; then
  echo "Installing Calico CNI..."
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
fi

# Wait for API server to become responsive
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


# Retry loop to wait for the join command
MAX_RETRIES=30
RETRY_DELAY=10
for i in $(seq 1 $MAX_RETRIES); do
  echo "Attempt $i to fetch join command from SSM..."
  JOIN_COMMAND=$(aws ssm get-parameter \
    --name "/k8s/worker-join-command" \
    --region eu-west-2 \
    --with-decryption \
    --query "Parameter.Value" \
    --output text) && break

  echo "Join command not available yet. Retrying in $RETRY_DELAY seconds..."
  sleep $RETRY_DELAY
done

if [ -z "$JOIN_COMMAND" ]; then
  echo "❌ Failed to retrieve join command from SSM after $MAX_RETRIES attempts"
  exit 1
fi

# Only join if not already joined
if [ ! -f /etc/kubernetes/kubelet.conf ]; then
  echo "Running kubeadm join..."
  $JOIN_COMMAND
fi

