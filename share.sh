#!/bin/bash
echo "net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_slow_start_after_idle = 0
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 32768
net.ipv4.ip_forward = 1" >>/etc/sysctl.conf
sysctl -p
echo "*               soft    nofile           1000000
*               hard    nofile          1000000" >/etc/security/limits.conf
echo "ulimit -SHn 1000000" >>/etc/profile

echo "请输入nodeid没有的话请先私聊站长："
read new_nodeid

echo "请输入运行端口："
read new_port

echo "请确认您要将nodeid设置为$new_nodeid ,端口设置为$new_port (y/n)"
read confirm

if [ "$confirm" == "y" ] || [ "$confirm" == "Y" ]; then
  sed -i "s/nodeId=.*/nodeId=$new_nodeid/g" .env
  sed -i "s/runPort=.*/runPort=$new_port/g" .env
  echo "修改已完成"
else
  echo "取消修改"
fi
docker-compose up -d
systemctl restart docker
docker ps -a
echo "启动完成,停止命令 docker-compose down , 启动命令 docker-compose up -d 感谢您的分享~"
