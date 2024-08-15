#!/bin/bash

RED="31m"      # Error message
GREEN="32m"    # Success message
YELLOW="33m"   # Warning message
BLUE="36m"     # Info message
colorEcho(){
    echo -e "\033[${1}${@:2}\033[0m" 1>& 2
}
HOST_ARCH=$(uname -m)
API=https://api.cjy.me

if [ "${HOST_ARCH}" = "x86_64" ]; then
    cp docker-compose1.yml docker-compose.yml
elif [ "${HOST_ARCH}" = "aarch64" ]; then
    cp docker-compose2.yml docker-compose.yml
else
    echo "不支持的架构: ${HOST_ARCH}"
    exit 1
fi



echo && echo -e " 分享小鸡@mjjcloudplatform ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  -- v0.4 2024.8.15 --"
colorEcho ${GREEN} "请先在网页添加主机信息后，再继续操作本脚本" 
while true; do
        colorEcho ${BLUE} "请输入主机识别ID："
        read new_nodeid

        if [[ "$new_nodeid" =~ ^[0-9]+$ ]]; then
                break
        else
                colorEcho ${RED} "主机识别ID是一个数字，请确认"
        fi
done


if [ ! -f /root/sh/.env ]; then
        echo "$new_nodeid=MJJ6688" > /root/.mcptoken
fi


new_token=$(grep "^$new_nodeid=" /root/.mcptoken | cut -d '=' -f 2)
if [ -z "$new_token" ]; then
        new_token="MJJ6688"
fi


while true; do
        echo "正在验证$new_nodeid的主机token：$new_token"
        verify=$(curl -s "$API/api/verify_server_token?token=$new_token&id=$new_nodeid")
        if [ "$verify" == "1" ] && [ "$new_token" == "MJJ6688" ]; then
                refresh=$(curl -s "$API/api/refresh_server_token?token=$new_token&id=$new_nodeid")
                if [[ $refresh =~ newToken=([a-zA-Z0-9]+) ]]; then
                        new_token=$(echo $refresh | cut -d '=' -f 2)
                else
                        echo "$refresh"
                        colorEcho ${RED} "刷新token失败,mcp提供的解锁功能将受限"
                        break
                fi
        elif [ "$verify" == "1" ]; then
                break
        else
                colorEcho ${RED} "验证失败，请输入账户全局token或 输入识别ID为：$new_nodeid 的主机token ，您可以在"我的主机"页面查询到："
                read new_token
        fi
done


if grep -q "^$new_nodeid=" /root/.mcptoken; then
        sed -i "s|^$new_nodeid=.*|$new_nodeid=$new_token|" /root/.mcptoken
else
        echo "$new_nodeid=$new_token" >> /root/.mcptoken
fi
token=$new_token
echo "token验证通过：$new_nodeid=$new_token"


while true; do
        colorEcho ${BLUE} "请输入服务端端口（与网页填写的服务源端端口保持一致）："
		read new_port

        if [[ "$new_port" =~ ^[0-9]+$ ]]; then
                break
        else
                colorEcho ${RED} "端口是一个数字，请确认"
        fi
done

sed -i "s/token=.*/token=$new_token/g" .env
sed -i "s/nodeId=.*/nodeId=$new_nodeid/g" .env
sed -i "s/runPort=.*/runPort=$new_port/g" .env

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
  if [ "${HOST_ARCH}" = "x86_64" ]; then
    echo "如果对接失败，请将下面日志发在群内求助："
    echo "docker logs --tail=100 mcpv2"
  elif [ "${HOST_ARCH}" = "aarch64" ]; then
    echo "如果对接失败，请将下面日志发在群内求助："
    echo "docker logs --tail=100 mcpv2"
    echo "docker logs --tail=100 mcpv2scar"
  else
      echo "不支持的架构: ${HOST_ARCH}"
      exit 1
  fi
