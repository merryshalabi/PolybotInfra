# These instructions are for Kubernetes v1.32.
KUBERNETES_VERSION=v1.32

sudo apt-get update
sudo apt-get install jq unzip ebtables ethtool -y

# install awscli
rm -rf aws awscliv2.zip
curl -sSLO "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
unzip -o -q awscliv2.zip


sudo ./aws/install

# Enable IPv4 packet forwarding. sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# Install cri-o kubelet kubeadm kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update
sudo apt-get install -y software-properties-common apt-transport-https ca-certificates curl gpg
sudo apt-get install -y cri-o kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# start the CRIO container runtime and kubelet
sudo systemctl start crio.service
sudo systemctl enable --now crio.service
sudo systemctl enable --now kubelet

# disable swap memory
swapoff -a

# add the command to crontab to make it persistent across reboots
(crontab -l ; echo "@reboot /sbin/swapoff -a") | crontab -

export PATH=$PATH:/usr/local/bin

# Wait for the join command to be available in SSM
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
  echo "❌ Failed to retrieve join command from SSM"
  exit 1
fi

# Join the cluster
$JOIN_COMMAND
