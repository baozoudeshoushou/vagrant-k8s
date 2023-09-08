## 设置
关闭 windows 防火墙

修改 Vagrantfile，配置 public 网络 ，ip 必须和宿主机一个网段

VM VirtualBox 设置为桥接模式，选择物理网卡

## 命令
vagrant ssh

修改密码
```
sudo passwd 
//.....输入两次新密码
```

ssh 配置
```
su root

vi /etc/ssh/sshd_config

添加如下配置：
PasswordAuthentication yes

重启 ssh 服务：
systemctl restart sshd.service
```