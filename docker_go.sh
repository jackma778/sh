#!/bin/bash
echo "请预先告知站长如下信息："
echo "IP|端口（和后面脚本要求输入的保持一致）|直连/中转|服务器位置|服务器运营商如aws/vir|是否需匿名/不匿名/半匿名捐赠|总流量限制（默认1T/月）"
echo "请输入nodeid（私聊站长获取）："
read new_nodeid

echo "请输入运行端口（刚刚告知站长的端口）："
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
  docker-compose up -d
  docker images
  docker ps -a
  docker logs v2ray
  echo "服务已启动完成 可尝试连接 如无法使用请将脚本执行期间的日志截图 感谢您的分享~"
  echo "停止命令 cd /root/sh $$ docker-compose down"
  echo "启动命令 cd /root/sh $$ docker-compose up -d"
  echo "启动状态下重启或改动了防火墙配置后需执行 systemctl restart docker"
  echo "卸载命令 cd /root/sh $$ docker-compose rm -s"
else
  echo "取消"
fi

