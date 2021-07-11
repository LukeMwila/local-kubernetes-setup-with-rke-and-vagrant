#!/bin/bash

# Enable ssh password authentication
echo "Enable SSH password authentication:"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd

# Set Root password
echo "Set root password:"
echo -e "iamadmin\niamadmin" | passwd root >/dev/null 2>&1

# Commands for all K8s nodes
# Add Docker GPG key, Docker Repo, install Docker and enable services
# Add repo and Install packages
sudo apt update
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y containerd.io docker-ce=5:19.03.12~3-0~ubuntu-bionic docker-ce-cli=5:19.03.12~3-0~ubuntu-bionic

# Create required directories
sudo mkdir -p /etc/systemd/system/docker.service.d

# Create daemon json config file
sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# Start and enable Services
sudo systemctl daemon-reload 
sudo systemctl restart docker
sudo systemctl enable docker

# Turn off swap
# The Kubernetes scheduler determines the best available node on 
# which to deploy newly created pods. If memory swapping is allowed 
# to occur on a host system, this can lead to performance and stability 
# issues within Kubernetes. 
# For this reason, Kubernetes requires that you disable swap in the host system.
# If swap is not disabled, kubelet service will not start on the masters and nodes
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a

# Turn off firewall
ufw disable

# Modify bridge adapter setting
# Configure sysctl.
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Ensure that the br_netfilter module is loaded
lsmod | grep br_netfilter