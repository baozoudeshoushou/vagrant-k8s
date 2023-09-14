#! /bin/bash

sudo /bin/bash /vagrant/configs/join.sh -v

cp /vagrant/configs/config /etc/kubernetes/admin.conf
export KUBECONFIG=/etc/kubernetes/admin.conf

sudo -i -u vagrant bash << EOF
mkdir -p /home/vagrant/.kube
sudo cp -i /vagrant/configs/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
EOF