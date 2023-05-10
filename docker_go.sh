#!/bin/bash
echo "https://share.cjy.me/ 登录后点击 共享节点  ："
echo "添加一个节点，输入节点信息并提交后，再继续操作本脚本"
echo "请输入节点id（和您刚刚在网页填写的节点id保持一致）："
read new_nodeid

echo "请输入服务端端口（和您刚刚在网页填写的服务端端口保持一致）："
read new_port

echo "请确认您要将nodeid设置为$new_nodeid ,端口设置为$new_port (y/n)"
read confirm

if [ "$confirm" == "y" ] || [ "$confirm" == "Y" ]; then
  echo "优化内核参数"
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
  echo "*               soft    nofile           1000000
  *               hard    nofile          1000000" >/etc/security/limits.conf
  echo "ulimit -SHn 1000000" >>/etc/profile
  source /etc/profile
  sysctl -p
  sed -i "s/nodeId=.*/nodeId=$new_nodeid/g" .env
  sed -i "s/runPort=.*/runPort=$new_port/g" .env
  echo "正在启动"
  docker compose up -d &&   echo "服务已启动完成 可尝试连接节点 在线状态需要3分钟左右更新 如无法使用请将脚本执行期间的日志截图 感谢您的分享~" || echo "启动失败"
  docker ps -a
  echo "停止命令 cd /root/sh && docker compose stop"
  echo "启动命令 cd /root/sh && docker compose up -d"
  echo "启动状态下重启或改动了防火墙配置后需执行 systemctl restart docker"
  echo "卸载命令 cd /root/sh && docker compose down"
else
  echo "取消"
fi

