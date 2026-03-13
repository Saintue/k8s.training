#!/bin/bash


# prep scritpt for k8s instalation (kubeadm)
# must be launched with sudo permission (or root)
# docker must be installed before script init

set -e 

echo "Start prep node for Kubernetes..."
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "📌 Loading core modules (overlay, br_netfilter)..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter


echo "Setting up sysctl for Kubernetes..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

echo "Downloading containerd..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "downloading req packets (conntrack, socat etc.)..."
sudo apt update
sudo apt install -y curl wget net-tools vim htop tmux conntrack socat ebtables ethtool

echo "Downloading kubeadm, kubelet, kubectl..."
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

echo ""
echo "Prep is done!"
echo "======================="
echo "Version of downloaded contents:"
kubeadm version
kubectl version --client
kubelet --version
echo ""
echo "check swap (Must be 0):"
free -h | grep Swap
echo "======================="
echo "Node is ready to join cluster!"