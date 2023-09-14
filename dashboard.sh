kubectl apply -f /vagrant/dashboard.yaml

kubectl apply -f /vagrant/yaml/admin-role.yaml

# 获取令牌用于登录 dashboard
# chrome 访问会提示不安全，随便点个空白输入 thisisunsafe 即可
kubectl -n kubernetes-dashboard describe secret `kubectl -n kubernetes-dashboard get secret|grep admin-token|cut -d " " -f1`|grep "token:"|tr -s " "|cut -d " " -f2