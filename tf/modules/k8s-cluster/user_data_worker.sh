#!/bin/bash
exec > /var/log/worker-init.log 2>&1
set -e

echo "🚀 Starting worker node setup..."

# ✅ Kubernetes version
KUBERNETES_VERSION=v1.32
REGION=eu-west-2
SSM_PARAM_NAME="/k8s/worker-join-command"

# ✅ Update and install required packages
echo "📦 Installing system packages..."
sudo apt-get update
sudo apt-get install -y jq unzip ebtables ethtool software-properties-common apt-transport-https ca-certificates curl gpg

# ✅ Install AWS CLI
echo "☁️ Installing AWS CLI..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install
export PATH=$PATH:/usr/local/bin

# ✅ Enable IP forwarding
echo "🔧 Enabling IPv4 forwarding..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# ✅ Add Kubernetes & CRI-O repositories
echo "🔑 Adding Kubernetes and CRI-O repositories..."
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:${KUBERNETES_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:${KUBERNETES_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

# ✅ Install CRI-O and Kubernetes
echo "📦 Installing CRI-O and Kubernetes components..."
sudo apt-get update
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# ✅ Disable swap
echo "🚫 Disabling swap..."
sudo swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -

# ✅ Enable and start services
echo "🔌 Starting services..."
sudo systemctl daemon-reexec
sudo systemctl enable --now crio
sudo systemctl enable kubelet

# ✅ Wait and fetch the join command from SSM
echo "🔑 Fetching kubeadm join command from SSM..."
MAX_RETRIES=30
RETRY_DELAY=10

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

# ✅ Join the cluster
echo "🤝 Running kubeadm join..."
eval "$JOIN_COMMAND"
echo "✅ Worker successfully joined the cluster."
