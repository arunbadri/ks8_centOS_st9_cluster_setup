#!/bin/bash
#
# Setup for Control Plane (Master) servers

set -euxo pipefail

NODENAME=$(hostname -s)

sudo kubeadm config images pull

echo "Preflight Check Passed: Downloaded All Required Images"

#sudo kubeadm init --apiserver-advertise-address=$CONTROL_IP --apiserver-cert-extra-sans=$CONTROL_IP --pod-network-cidr=$POD_CIDR --service-cidr=$SERVICE_CIDR --node-name "$NODENAME" --ignore-preflight-errors Swap
sudo kubeadm init --apiserver-advertise-address=$CONTROL_IP --apiserver-cert-extra-sans=$CONTROL_IP --pod-network-cidr=$POD_CIDR --service-cidr=$SERVICE_CIDR --node-name "$NODENAME" --control-plane-endpoint=$HA_PROXY_IP":"$HA_PROXY_PORT --upload-certs --ignore-preflight-errors Swap

mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

# Save Configs to shared /Vagrant location

# For Vagrant re-runs, check if there is existing configs in the location and delete it for saving new configuration.

config_path="/vagrant/configs"

if [ -d $config_path ]; then
  rm -f $config_path/*
else
  mkdir -p $config_path
fi

cp -i /etc/kubernetes/admin.conf $config_path/config
touch $config_path/join_master.sh
chmod +x $config_path/join_master.sh

touch $config_path/join_worker.sh
chmod +x $config_path/join_worker.sh


create_cert_cmd=$(sudo kubeadm init phase upload-certs --upload-certs | grep -vw -e certificate -e Namespace)
create_token_print_cmd_master=$(sudo kubeadm token create --certificate-key $create_cert_cmd --print-join-command)
create_token_print_cmd_worker=$(sudo kubeadm token create --print-join-command)


echo $create_token_print_cmd_master --apiserver-advertise-address=\$1 > $config_path/join_master.sh
echo $create_token_print_cmd_worker > $config_path/join_worker.sh

#echo $create_token_print_cmd_master --apiserver-advertise-address=\$1 > $config_path/join_master.sh
#echo $create_token_print_cmd_worker --apiserver-advertise-address=\$1 > $config_path/join_worker.sh


#echo $(kubeadm token create --print-join-command) --control-plane --certificate-key $(kubeadm init phase upload-certs --upload-certs | grep -vw -e certificate -e Namespace) > $config_path/join_master.sh
#echo $(kubeadm token create --print-join-command) --certificate-key $(kubeadm init phase upload-certs --upload-certs | grep -vw -e certificate -e Namespace) > $config_path/join_worker.sh

# Install Calico Network Plugin

curl https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml -O

kubectl apply -f calico.yaml

sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
sudo chmod 755 $config_path/config 
EOF

# Install Metrics Server

kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml

