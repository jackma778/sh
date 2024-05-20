#!/bin/bash
echo "  -- v0.3 2024.5.20 -- "
HOST_ARCH=$(uname -m)
if [ "${HOST_ARCH}" = "x86_64" ]; then
    sed -i '$s|.*|    command: sh -c "apt update -y \&\& apt install ca-certificates -y \&\& chmod +x /root/v2scar \&\& /root/v2scar -id=${nodeId} -gp=v2ray:8079"|' docker-compose.yml
elif [ "${HOST_ARCH}" = "aarch64" ]; then
    sed -i '$s|.*|    command: sh -c "apt update -y \&\& apt install ca-certificates -y \&\& chmod +x /root/v2scar_armlinux \&\& /root/v2scar_armlinux -id=${nodeId} -gp=v2ray:8079"|' docker-compose.yml
else
   echo "不支持的架构: ${HOST_ARCH}"
   exit 1
fi
echo "https://share.cjy.me 添加主机信息后，再继续操作本脚本"
echo "请输入主机识别ID："
read new_nodeid

echo "请输入服务端端口（和您刚刚在网页填写的服务端端口保持一致）："
read new_port

echo "请确认您要将主机识别ID设置为$new_nodeid ,端口设置为$new_port (y/n)"
read confirm

if [ "$confirm" == "y" ] || [ "$confirm" == "Y" ]; then
    # 优化内核参数 检查是否存在重复配置项
    if ! grep -q "net.ipv4.tcp_congestion_control = bbr" /etc/sysctl.conf; then
		echo "net.ipv4.tcp_retries2 = 8
		net.ipv4.tcp_slow_start_after_idle = 0
		fs.file-max = 1000000
		net.core.default_qdisc = fq
		net.ipv4.tcp_congestion_control = bbr
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
		net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
        sysctl -p
    fi

    # 优化系统参数 检查是否存在重复配置项
    if ! grep -q "*               soft    nofile           1000000" /etc/security/limits.conf; then
        echo "*               soft    nofile           1000000
        *               hard    nofile          1000000" > /etc/security/limits.conf
    fi
    
    # 优化系统参数 检查是否存在重复配置项
    if ! grep -q "ulimit -SHn 1000000" /etc/profile; then
        echo "ulimit -SHn 1000000" >> /etc/profile
        source /etc/profile
    fi
  sed -i "s/nodeId=.*/nodeId=$new_nodeid/g" .env
  sed -i "s/runPort=.*/runPort=$new_port/g" .env
  echo "正在启动"
  docker compose up -d &&   echo "服务已启动完成 可尝试连接节点 在线状态需要3分钟左右更新 如无法使用请将脚本执行期间的日志截图 感谢您的分享~" || echo "启动失败"
  if crontab -l | grep -q "mcpv2scar"; then
    echo "pass"
  else
    echo "add crontab"
    minute=$(shuf -i 0-59 -n 1)
    hour=$(shuf -i 0-23 -n 1)
    weekday=$(shuf -i 0-6 -n 1)
    (crontab -l ; echo "$minute $hour * * $weekday docker restart mcpv2 && docker restart mcpv2scar") | crontab -
  fi
  docker ps -a
  echo "停止命令 cd /root/sh && docker compose stop"
  echo "启动命令 cd /root/sh && docker compose up -d"
  echo "启动状态下重启或改动了防火墙配置后需执行 systemctl restart docker"
  echo "卸载命令 cd /root/sh && docker compose down"
else
  echo "取消"
fi

