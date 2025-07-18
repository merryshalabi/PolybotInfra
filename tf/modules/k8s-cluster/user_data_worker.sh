#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -e

# Kubernetes version
KUBERNETES_VERSION=v1.32

# Install required tools
sudo apt-get update
sudo apt-get install -y jq unzip ebtables ethtool software-properties-common apt-transport-https ca-certificates curl gpg

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Enable IPv4 forwarding
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/k8s.conf
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system


sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list


curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/cri-o.list


# Install CRI-O and Kubernetes tools
sudo apt-get update
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl cri-o

# Start services
sudo systemctl daemon-reexec
sudo systemctl enable --now crio
sudo systemctl enable --now kubelet

# Disable swap
sudo swapoff -a
(crontab -l ; echo "@reboot /sbin/swapoff -a") | crontab -


# Wait for join command from SSM
echo "🔑 Fetching kubeadm join command from SSM..."
MAX_RETRIES=30
RETRY_DELAY=10

REGION="eu-west-2"
SSM_PARAM_NAME="/k8s/worker-join-command"

for i in $(seq 1 $MAX_RETRIES); do
  echo "Attempt $i to fetch join command..."
  JOIN_COMMAND=$(aws ssm get-parameter \
    --name "$SSM_PARAM_NAME" \
    --region "$REGION" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text 2>/dev/null) && break

  echo "⏳ Not available yet. Retrying in $RETRY_DELAY seconds..."
  sleep $RETRY_DELAY
done

if [ -z "$JOIN_COMMAND" ]; then
  echo "❌ Failed to retrieve join command after $MAX_RETRIES attempts"
  exit 1
fi

# Mount BPF filesystem (required for Calico eBPF dataplane)
sudo mount bpffs -t bpf /sys/fs/bpf || echo "bpffs already mounted"
echo "bpffs /sys/fs/bpf bpf defaults 0 0" | sudo tee -a /etc/fstab
# Wait until the control plane API server is reachable
CONTROL_PLANE_IP=$(echo "$JOIN_COMMAND" | awk '{print $3}' | cut -d: -f1)

echo "⏳ Waiting for control plane API server to be reachable at $CONTROL_PLANE_IP:6443 ..."
for i in $(seq 1 30); do
  if nc -z $CONTROL_PLANE_IP 6443; then
    echo "✅ Control plane is reachable!"
    break
  else
    echo "🔁 Control plane not ready yet... waiting ($i/30)"
    sleep 10
  fi
done

echo "🤝 Running kubeadm join..."
JOIN_SUCCESS=false
for attempt in $(seq 1 10); do
  echo "🔁 Attempt $attempt to join the cluster..."
  if eval "$JOIN_COMMAND"; then
    echo "✅ Worker successfully joined the cluster."
    JOIN_SUCCESS=true
    break
  else
    echo "❌ kubeadm join failed. Retrying in 15 seconds..."
    sleep 15
  fi
done

if [ "$JOIN_SUCCESS" = false ]; then
  echo "❌ kubeadm join failed after multiple attempts"
  exit 1
fi

