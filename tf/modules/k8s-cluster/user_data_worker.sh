#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -e

# Kubernetes version
KUBERNETES_VERSION=v1.32

# Update system and install dependencies
sudo apt-get update
sudo apt-get install -y jq unzip ebtables ethtool software-properties-common apt-transport-https ca-certificates curl gpg

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Enable IPv4 forwarding
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# Add Kubernetes and CRI-O repositories
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:${KUBERNETES_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:${KUBERNETES_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Start CRI-O, delay kubelet until after join
sudo systemctl enable --now crio
sudo systemctl disable kubelet

# Disable swap
sudo swapoff -a
grep -q '/sbin/swapoff -a' <(crontab -l 2>/dev/null) || (crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -

# Add AWS CLI to PATH
export PATH=$PATH:/usr/local/bin

# Wait for join command to appear in SSM Parameter Store
MAX_RETRIES=30
RETRY_DELAY=10
for i in $(seq 1 $MAX_RETRIES); do
  echo "Attempt $i to fetch join command from SSM..."
  JOIN_COMMAND="$(/usr/local/bin/aws ssm get-parameter \
    --name "/k8s/worker-join-command" \
    --region eu-west-2 \
    --with-decryption \
    --query "Parameter.Value" \
    --output text)" && break
  echo "Join command not available yet. Retrying in $RETRY_DELAY seconds..."
  sleep $RETRY_DELAY
done

if [ -z "$JOIN_COMMAND" ]; then
  echo "❌ Failed to retrieve join command from SSM after $MAX_RETRIES attempts."
  exit 1
fi

# Run the join command
eval "$JOIN_COMMAND" && echo "✅ Worker successfully joined the cluster."

# Now start kubelet
sudo systemctl enable kubelet
sudo systemctl restart kubelet
