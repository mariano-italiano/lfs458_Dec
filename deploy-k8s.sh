#!/bin/bash

echo "[TASK 1] Create module configuration file for containerd"
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

# load modules
modprobe overlay >/dev/null 2>&1
modprobe br_netfilter >/dev/null 2>&1

echo "[TASK 2] Set system configurations for Kubernetes networking"
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# apply new settings
sysctl --system >/dev/null 2>&1

echo "[TASK 3] Install containerd runtime"
apt-get update >/dev/null 2>&1
apt-get install -y containerd >/dev/null 2>&1

echo "[TASK 4] Generate default containerd configuration and save to the newly created default file"
mkdir -p /etc/containerd >/dev/null 2>&1
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1

echo "[TASK 5] Update containerd option for System Cgroup"
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml >/dev/null 2>&1

# apply new settings
systemctl restart containerd >/dev/null 2>&1

echo "[TASK 6] Disable SWAP"
swapoff -a >/dev/null 2>&1
sed -i 's/.* none.* swap.* sw.*/#&/' /etc/fstab >/dev/null 2>&1

echo "[TASK 7] Install depencdency packages"
apt-get update >/dev/null 2>&1
apt-get install -y apt-transport-https curl >/dev/null 2>&1

echo "[TASK 8] Add GPG key for K8s repo"
mkdir -p /etc/apt/keyrings
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null 2>&1

echo "[TASK 9] Add K8s repository"
mkdir -p /etc/apt/keyrings/
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null 2>&1

# refresh repo
apt-get update >/dev/null 2>&1

echo "[TASK 10] Install K8s"
apt-get install -y kubelet=1.30.6-1.1 kubeadm=1.30.6-1.1 kubectl=1.30.6-1.1 >/dev/null 2>&1

echo "[TASK 11] Turn off automatic updates"
apt-mark hold kubelet kubeadm kubectl >/dev/null 2>&1

if [[ $(hostname) =~ .*master.* ]] || [[  $(hostname) =~ .*cp.* ]]
then
        # INSTALL BASH COMPLETION
        sudo apt-get install bash-completion >/dev/null 2>&1
        echo 'source <(kubectl completion bash)' >>~/.bashrc
        source ~/.bashrc
        echo "[TASK 12] Initialize the cluster"
        echo " Please initialize the cluster on master node using 'kubeadm init' command"
fi

if [[ $(hostname) =~ .*worker.* ]]
then
        echo "[TASK 12] Join worker nodes to the control plane node"
        echo " Please join the worker nodes using the comand you received during the cluster initialization"
        echo " Alternatively you can use that command to re-generate it: 'sudo kubeadm token create --print-join-command'"
fi
