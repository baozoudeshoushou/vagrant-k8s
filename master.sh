#! /bin/bash

MASTER_IP="192.168.31.111"
NODENAME=$(hostname -s)
SERVICE_CIDR="10.96.0.0/12"
POD_CIDR="10.244.0.0/16"
KUBE_VERSION=v1.21.1

# kubeadm init
sudo kubeadm init \
  --kubernetes-version=$KUBE_VERSION \
  --apiserver-advertise-address=$MASTER_IP \
  --service-cidr=$SERVICE_CIDR \
  --pod-network-cidr=$POD_CIDR \
  --node-name=$NODENAME \
  --ignore-preflight-errors=Swap \
  --image-repository=registry.aliyuncs.com/google_containers
  
# Your Kubernetes control-plane has initialized successfully!

# To start using your cluster, you need to run the following as a regular user:

#   mkdir -p $HOME/.kube
#   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#   sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Alternatively, if you are the root user, you can run:

#   export KUBECONFIG=/etc/kubernetes/admin.conf

# You should now deploy a pod network to the cluster.
# Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
#   https://kubernetes.io/docs/concepts/cluster-administration/addons/

# Then you can join any number of worker nodes by running the following on each as root:

# kubeadm join 192.168.31.111:6443 --token q81nlk.zyrnn2hoajvx65qm \
#         --discovery-token-ca-cert-hash sha256:ad34fd929e062c30993d6ace90bcf14a5ae3e1fbd4f5e0b8793013e92ed7ea82 

# 要使非 root 用户可以运行 kubectl，请运行以下命令， 它们也是 kubeadm init 输出的一部分
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# save configs
config_path="/vagrant/configs"

if [ -d $config_path ]; then
   sudo rm -f $config_path/*
else
   sudo mkdir -p $config_path
fi

sudo cp -i /etc/kubernetes/admin.conf $config_path/config
sudo touch $config_path/join.sh
sudo chmod +x $config_path/join.sh

kubeadm token create --print-join-command > $config_path/join.sh

# 必须部署一个基于 Pod 网络插件的 容器网络接口 (CNI)，以便你的 Pod 可以相互通信。
# install calico network plugin

# sudo wget https://docs.projectcalico.org/manifests/calico.yaml
# sudo kubectl apply -f calico.yaml

# sudo wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
# sudo kubectl apply -f kube-flannel.yml
sudo kubectl apply -f /vagrant/kube-flannel.yml

sudo -i -u vagrant bash << EOF
mkdir -p /home/vagrant/.kube
sudo cp -i /vagrant/configs/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
EOF