#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -e

KUBERNETES_VERSION="v1.32"

# Set hostname for control plane node
hostnamectl set-hostname control-plane

# Wait for cloud-init and network to be ready
sleep 30

# Ensure required keyrings directory exists
sudo mkdir -p /etc/apt/keyrings

# Basic system dependencies
sudo apt-get update
sudo apt-get install -y jq unzip ebtables ethtool curl gpg apt-transport-https ca-certificates software-properties-common

# Install AWS CLI
curl -sSLO "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
unzip -o awscliv2.zip
sudo ./aws/install

# Enable IPv4 forwarding
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# Add Kubernetes repo and key
curl -fsSL https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:${KUBERNETES_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Add CRI-O repo and key
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

# Update package index
sudo apt-get update

# Install Kubernetes + CRI-O
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Start CRI-O and kubelet
sudo systemctl enable --now crio
sudo systemctl enable --now kubelet

# Disable swap (required for kubeadm)
sudo swapoff -a

# Persist swapoff on reboot
grep -q '/sbin/swapoff -a' <(crontab -l 2>/dev/null) || (crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab -
