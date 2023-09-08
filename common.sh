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

# preload coredns for special handling
# 这里应该放在 common
COREDNS_VERSION=1.8.0
sudo docker pull registry.aliyuncs.com/google_containers/coredns:$COREDNS_VERSION
sudo docker tag registry.aliyuncs.com/google_containers/coredns:$COREDNS_VERSION registry.aliyuncs.com/google_containers/coredns/coredns:v$COREDNS_VERSION
docker load < /vagrant/flanneld-v0.22.2-dirty-amd64.docker
sudo docker tag quay.io/coreos/flannel:v0.22.2-dirty-amd64 docker.io/flannel/flannel:v0.22.2

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