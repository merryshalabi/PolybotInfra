#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -e

echo "🚀 Starting worker node setup..."

# ✅ Use a working version of Kubernetes
KUBERNETES_VERSION=v1.32

# ✅ Update system and install dependencies
echo "📦 Installing base packages..."
sudo apt-get update
sudo apt-get install -y jq unzip ebtables ethtool software-properties-common apt-transport-https ca-certificates curl gpg

# ✅ Install AWS CLI v2
echo "☁️ Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

# ✅ Enable IPv4 forwarding
echo "🔧 Enabling IP forwarding..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# ✅ Add Kubernetes & CRI-O repositories
echo "🔑 Adding Kubernetes and CRI-O repositories..."
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:${KUBERNETES_VERSION}/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:${KUBERNETES_VERSION}/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/cri-o.list

# ✅ Install Kubernetes components
echo "📦 Installing Kubernetes components..."
sudo apt-get update
sudo apt-get install -y cri-o kubelet kubeadm kubectl || {
  echo "❌ Failed to install Kubernetes packages"
  exit 1
}

sudo apt-mark hold kubelet kubeadm kubectl

# ✅ Disable swap
echo "🚫 Disabling swap..."
sudo swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -

# ✅ Start CRI-O (kubelet will start after joining)
echo "🔌 Starting CRI-O..."
sudo systemctl enable --now crio
sudo systemctl enable kubelet

# ✅ Add AWS CLI to PATH
export PATH=$PATH:/usr/local/bin

# ✅ Fetch the join command from SSM Parameter Store
MAX_RETRIES=30
RETRY_DELAY=10
for i in $(seq 1 $MAX_RETRIES); do
  echo "🔍 Attempt $i to fetch join command from SSM..."
  JOIN_COMMAND=$(/usr/local/bin/aws ssm get-parameter \
    --name "/k8s/worker-join-command" \
    --region eu-west-2 \
    --with-decryption \
    --query "Parameter.Value" \
    --output text) && break
  echo "⏳ Join command not available yet. Retrying in $RETRY_DELAY seconds..."
  sleep $RETRY_DELAY
done

if [ -z "$JOIN_COMMAND" ]; then
  echo "❌ Failed to retrieve join command from SSM after $MAX_RETRIES attempts"
  exit 1
fi

# ✅ Join the Kubernetes cluster
echo "🔗 Joining the cluster..."
eval "$JOIN_COMMAND" && echo "✅ Successfully joined the cluster."

