# -*- mode: ruby -*-
# vi: set ft=ruby :
# on win10, you need `vagrant plugin install vagrant-vbguest --plugin-version 0.21` and change synced_folder.type="virtualbox"
# reference `https://www.dissmeyer.com/2020/02/11/issue-with-centos-7-vagrant-boxes-on-windows-10/`


Vagrant.configure("2") do |config|
  config.vm.box_check_update = false
  config.vm.provider 'virtualbox' do |vb|
  vb.customize [ "guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 1000 ]
  end  
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
  $num_instances = 3
  $etcd_cluster = "node1=http://192.168.31.111:2380"
  (1..$num_instances).each do |i|
    config.vm.define "node#{i}" do |node|
      node.vm.box = "centos/7"
      node.vbguest.installer_options = { allow_kernel_upgrade: true }
      node.vm.box_version = "2004.01"
      node.vm.hostname = "node#{i}"
      ip = "192.168.31.#{i+110}"
      node.vm.network "public_network", ip: ip
      node.vm.provider "virtualbox" do |vb|
        vb.memory = "4096"
        vb.cpus = 2
        vb.name = "node#{i}"
      end
    end
  end
end