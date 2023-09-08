# ------------------------------ common start ------------------------------

#! /bin/bash

# disable swap 
sudo swapoff -a
sudo sed -ri 's/.*swap.*/#&/' /etc/fstab 

# disable firewall
systemctl stop firewalld
systemctl disable firewalld

# 安装需要的软件包
yum install -y yum-utils wget ca-certificates ntp

# enable ntp to sync time
systemctl start ntpd
systemctl enable ntpd

# set nameserver
echo "nameserver 8.8.8.8">/etc/resolv.conf

# set host name resolution
cat >> /etc/hosts <<EOF
192.168.31.111 node1
192.168.31.112 node2
192.168.31.113 node3
EOF

# 中央仓库
yum-config-manager --add-repo http://download.docker.com/linux/centos/docker-ce.repo

# 阿里仓库
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# Install Docker
yum -y install docker-ce

# 设置 Docker 源
cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors" : [
        "https://hub-mirror.c.163.com​",
        "https://mirror.baidubce.com​",
        "https://dockerproxy.com",
        "https://docker.nju.edu.cn"
  ]
}
EOF

# start docker
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.conf
sysctl -p
echo 'enable docker'
systemctl daemon-reload
systemctl enable docker
systemctl start docker

# preload coredns for special handling
# 这里应该放在 common
COREDNS_VERSION=1.8.0
sudo docker pull registry.aliyuncs.com/google_containers/coredns:$COREDNS_VERSION
sudo docker tag registry.aliyuncs.com/google_containers/coredns:$COREDNS_VERSION registry.aliyuncs.com/google_containers/coredns/coredns:v$COREDNS_VERSION
docker load < /vagrant/flanneld-v0.22.2-dirty-amd64.docker
sudo docker tag quay.io/coreos/flannel:v0.22.2-dirty-amd64 docker.io/flannel/flannel:v0.22.2

# 设置 K8S 镜像
# Google：baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
# Ali：baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
# 如果由于该 Red Hat 的发行版无法解析 basearch 导致获取 baseurl 失败，请将 \$basearch 替换为你计算机的架构。 
# 输入 uname -m 以查看该值。 例如，x86_64 的 baseurl URL 可以是：https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
# cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
# [kubernetes]
# name=Kubernetes
# baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
# enabled=1
# gpgcheck=1
# gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
# exclude=kubelet kubeadm kubectl
# EOF
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
EOF

# 将 SELinux 设置为 permissive 模式（相当于将其禁用）
# 通过运行命令 setenforce 0 和 sed ... 将 SELinux 设置为 permissive 模式可以有效地将其禁用。 
# 这是允许容器访问主机文件系统所必需的，而这些操作是为了例如 Pod 网络工作正常。
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# install kubelet、kubeadm、kubectl
sudo yum install -y kubelet-1.21.1-0 kubeadm-1.21.1-0 kubectl-1.21.1-0 --disableexcludes=kubernetes

sudo systemctl enable --now kubelet

# ------------------------------ common end ------------------------------


# ------------------------------ master start ------------------------------

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
  --ignore-preflight-errors=Swap
  --image-repository=registry.aliyuncs.com/google_containers

sudo kubeadm init \
  --kubernetes-version=v1.21.1 \
  --apiserver-advertise-address="192.168.31.111" \
  --service-cidr="10.96.0.0/12" \
  --pod-network-cidr="10.244.0.0/16" \
  --node-name=$(hostname -s) \
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

# ------------------------------ master end ------------------------------


# ------------------------------ node start ------------------------------

#! /bin/bash

/bin/bash /vagrant/configs/join.sh -v

sudo -i -u vagrant bash << EOF
mkdir -p /home/vagrant/.kube
sudo cp -i /vagrant/configs/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
EOF

# ------------------------------ node end ------------------------------


# ------------------------------ 其他命令 ------------------------------
vi ~/.bashrc 

export http_proxy="http://192.168.31.107:7890"
export https_proxy="http://192.168.31.107:7890"
export ftp_proxy=$http_proxy

source ~/.bashrc

sudo mkdir -p /etc/systemd/system/docker.service.d
sudo vi /etc/systemd/system/docker.service.d/http-proxy.conf

[Service]
Environment="HTTP_PROXY=http://192.168.31.107:7890"
Environment="HTTPS_PROXY=https://192.168.31.107:7890"

# 重新加载配置文件，重启 dockerd
sudo systemctl daemon-reload
sudo systemctl restart docker

# 检查确认环境变量已经正确配置
sudo systemctl show --property=Environment docker
# 从 docker info 的结果中查看配置项
docker info
# 查看 docker 状态
systemctl status docker

sudo mkdir ~/.docker
sudo vi ~/.docker/config.json

{
 "proxies": {
   "default": {
     "httpProxy": "http://192.168.31.107:7890",
     "httpsProxy": "https://192.168.31.107:7890"
   }
 }
}

docker pull flannel/flannel-cni-plugin:v1.2.0
docker pull flannel/flannel:v0.22.2

sudo HTTP_PROXY=http://192.168.31.107:7890/ docker pull flannel/flannel:v0.22.2 

docker load < flanneld-v0.22.2-dirty-amd64.docker
sudo docker tag quay.io/coreos/flannel:v0.22.2-dirty-amd64 docker.io/flannel/flannel:v0.22.2

kubectl get nodes -o wide
kubectl get pods --all-namespaces
kubectl -n kube-system get all -o wide