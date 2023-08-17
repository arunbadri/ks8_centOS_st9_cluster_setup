#filename=bootstrap_nfs.sh

# Update hosts file
echo "[TASK 1] Update /etc/hosts file"
# cat >>/etc/hosts<<EOF
# 10.1.0.5 nfs-server
# 10.1.0.21 master-node01
# 10.1.0.21 master-node02
# 10.1.0.11 worker-node01
# 10.1.0.12 worker-node02
# EOF

echo "[TASK 2] Download and install NFS server"
#yes| sudo pacman -S nfs-utils
sudo yum install nfs-utils -y

echo "[TASK 3] Create a kubedata directory"
mkdir -p /srv/nfs/kubedata
mkdir -p /srv/nfs/kubedata/db
mkdir -p /srv/nfs/kubedata/storage
mkdir -p /srv/nfs/kubedata/logs

echo "[TASK 4] Update the shared folder access"
chmod -R 777 /srv/nfs/kubedata

echo "[TASK 5] Make the kubedata directory available on the network"
cat >>/etc/exports<<EOF
/srv/nfs/kubedata    *(rw,sync,no_subtree_check,no_root_squash)
EOF

echo "[TASK 6] Export the updates"
sudo exportfs -rav

echo "[TASK 7] Enable NFS Server"
sudo systemctl enable nfs-server

echo "[TASK 8] Start NFS Server"
sudo systemctl start nfs-server