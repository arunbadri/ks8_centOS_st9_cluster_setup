#!/bin/bash
#
# Common setup for all servers (Control Plane and Nodes)

set -euxo pipefail

# Variable Declaration

# DNS Setting update in CentOS
if [ ! -d /etc/NetworkManager/conf.d ]; then
	sudo mkdir /etc/NetworkManager/conf.d/
fi
cat <<EOF | sudo tee /etc/NetworkManager/conf.d/dns_servers.conf
[main]
dns=none
EOF
sudo systemctl reload NetworkManager
echo ${DNS_SERVERS}|tr -s ' ' '\n'|awk '{print "nameserver "$0}'|sudo tee -a /etc/resolv.conf
sudo systemctl reload NetworkManager
sudo cat /etc/resolv.conf

# disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab


sudo yum update -y

# Disable SELINUX
sudo cat /etc/sysconfig/selinux | grep SELINUX=
sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
sudo cat /etc/sysconfig/selinux | grep SELINUX=
sudo setenforce 0



### Disable the Firewall ########
sudo systemctl stop firewalld.service
sudo systemctl disable firewalld
#sudo systemctl status firewalld



# Create the .conf file to load the modules at bootup
cat <<EOF | sudo tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF



sudo modprobe overlay
sudo modprobe br_netfilter

# Set up required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
sudo sysctl -p

#validate
sudo sysctl -a | grep net.bridge.bridge-nf-call-iptables
sudo sysctl -a | grep net.bridge.bridge-nf-call-ip6tables
sudo sysctl -a | grep net.ipv4.ip_forward

# Install CRI-O Runtime

VERSION="$(echo ${KUBERNETES_VERSION} | grep -oE '[0-9]+\.[0-9]+')"




cat >> /etc/default/crio << EOF
${ENVIRONMENT}
EOF
# sudo systemctl daemon-reload
# sudo systemctl enable crio --now
sudo yum update -y
#sudo su -
sudo curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/devel:kubic:libcontainers:stable.repo
sudo curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo
sudo yum install crio -y
#sudo systemctl status crio
sudo systemctl start crio
sudo systemctl enable crio

echo "CRI runtime installed successfully"

sudo yum update -y

## Install Ks8
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
sudo yum update -y


#sudo dnf --showduplicates list kubelet
#sudo dnf --showduplicates list kubectl
#sudo dnf --showduplicates list kubeadm

sudo dnf install -y kubelet-"$KUBERNETES_VERSION" kubectl-"$KUBERNETES_VERSION" kubeadm-"$KUBERNETES_VERSION"

sudo yum update -y
sudo dnf install -y jq




sudo systemctl start kubelet
sudo systemctl enable kubelet

local_ip="$(ip --json a s | jq -r '.[] | if .ifname == "eth1" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
cat > /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
${ENVIRONMENT}
EOF

