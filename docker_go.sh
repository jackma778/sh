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



installV2Ray(){
docker ps | grep mcpv2
if [ $? -eq 0 ];then
        colorEcho ${RED} "检测到mcpv2已安装，请勿重复安装"
        exit 1
fi
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


new_port=$(curl -s "$API/api/refresh_server_port?token=$new_token&id=$new_nodeid&show=1")

sed -i "s/token=.*/token=$new_token/g" .env
sed -i "s/nodeId=.*/nodeId=$new_nodeid/g" .env
sed -i "s/runPort=.*/runPort=$new_port/g" .env

# 优化内核参数 检查是否存在重复配置项
if ! grep -q "^net.ipv4.tcp_congestion_control = bbr" /etc/sysctl.conf; then
    cat <<EOF >> /etc/sysctl.conf
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
    sysctl -p
fi

if ! grep -q "^net.nf_conntrack_max = 20971520" /etc/sysctl.conf; then
    cat <<EOF >> /etc/sysctl.conf
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.ip_forward = 1
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_rmem = 4096 87380 10485760
net.ipv4.tcp_wmem = 4096 16384 10485760
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 32768
net.nf_conntrack_max = 20971520
EOF
    sysctl -p
fi


if ! grep -q "*               soft    nofile           1000000" /etc/security/limits.conf; then
    echo "*               soft    nofile           1000000
*               hard    nofile          1000000" > /etc/security/limits.conf
fi

if ! grep -q "^ulimit -SHn 1000000" /etc/profile; then
    echo "ulimit -SHn 1000000" >> /etc/profile
    source /etc/profile
fi

  echo "正在启动"
  docker compose up -d &&   echo "服务已启动完成 可尝试连接节点 在线状态需要3分钟左右更新 如无法使用请将脚本执行期间的日志截图 感谢您的分享~" || echo "启动失败"
  if crontab -l | grep -q "mcpv2"; then
    echo "pass"
  else
    echo "add crontab"
    minute=$(shuf -i 0-59 -n 1)
    hour=$(shuf -i 3-6 -n 1)
    weekday=$(shuf -i 0-6 -n 1)
    if [ "${HOST_ARCH}" = "x86_64" ]; then
        (crontab -l ; echo "$minute $hour * * $weekday docker restart mcpv2") | crontab -
    elif [ "${HOST_ARCH}" = "aarch64" ]; then
        (crontab -l ; echo "$minute $hour * * $weekday docker restart mcpv2 mcpv2scar") | crontab -
    fi
  fi
  docker ps -a
}
update_geo(){
        DAT_PATH="/root/sh"
        DOWNLOAD_LINK_GEOIP="https://github.com/v2fly/geoip/releases/latest/download/geoip.dat"
        DOWNLOAD_LINK_GEOSITE="https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat"
        wget --no-check-certificate -O "${DAT_PATH}/geoip.dat" "${DOWNLOAD_LINK_GEOIP}"
        wget --no-check-certificate -O "${DAT_PATH}/geosite.dat" "${DOWNLOAD_LINK_GEOSITE}"
        chmod 644 "${DAT_PATH}"/*.dat
}
refreshPort(){
    docker ps -a | grep mcpv2
    if [ $? -ne 0 ];then
        colorEcho ${RED} "未检测到mcp服务端，请先安装"
        exit 1
    fi
    new_nodeid=`grep ^nodeId= .env | cut -d '=' -f 2`
    new_token=`grep ^token= .env | cut -d '=' -f 2`
    if [ -z "$new_token" ]; then
        colorEcho ${RED} "您的mcp服务端过旧,无法使用脚本更换端口，请先执行卸载后重新安装"
        exit 0
    fi
    while true; do
            echo "正在验证$nodeid的主机token：$new_token"
            verify=$(curl -s "$API/api/verify_server_token?token=$new_token&id=$new_nodeid")
            if [ "$verify" == "1" ]; then
                    sed -i "s|^$new_nodeid=.*|$new_nodeid=$new_token|" /root/.mcptoken
                    echo "token验证通过：$new_nodeid=$new_token"
                    break
            else
                    colorEcho ${RED} "验证失败，请输入账户全局token或 输入识别ID为：$new_nodeid 的主机token ，您可以在"我的主机"页面查询到："
                    read new_token
            fi
    done
    read -p "请输入需要更换的新端口 (直接回车随机生成): " new_port
    if [ -z "$new_port" ]; then
            new_port=$((RANDOM % 49001 + 1000))
    fi
    refresh_port=$(curl -s "$API/api/refresh_server_port?token=$new_token&id=$new_nodeid&port=$new_port&docker=1")
            if [[ $refresh_port =~ ^newPort= ]]; then
                    new_port=$(echo $refresh_port | cut -d '=' -f 2)
                    env_port=$(echo $new_port | sed 's/(.*//')
                    sed -i "s|^runPort=.*|runPort=$env_port|" .env
                    docker compose down && docker compose up -d
                    colorEcho ${GREEN} "端口更换成功，新端口为：$new_port"
            else
                    colorEcho ${RED} "端口更换失败，失败原因为：$refresh_port"
                    exit 1
            fi

}
updateCompose(){
    docker ps -a | grep mcpv2
    if [ $? -ne 0 ];then
        colorEcho ${RED} "未检测到mcp服务端，请先安装"
        exit 1
    fi
    docker compose down && docker compose up -d
}
restartV2ray(){
  ntpdate time.windows.com && hwclock -w
  if [ "${HOST_ARCH}" = "x86_64" ]; then
        docker restart mcpv2
  elif [ "${HOST_ARCH}" = "aarch64" ]; then
        docker restart mcpv2 mcpv2scar
  else
      echo "不支持的架构: ${HOST_ARCH}"
      exit 1
  fi
}
remove(){
        docker compose down
}
stopV2ray(){
  if [ "${HOST_ARCH}" = "x86_64" ]; then
        docker stop mcpv2
  elif [ "${HOST_ARCH}" = "aarch64" ]; then
        docker stop mcpv2 mcpv2scar
  else
      echo "不支持的架构: ${HOST_ARCH}"
      exit 1
  fi
}
showLog(){
  sleep 3
  if [ "${HOST_ARCH}" = "x86_64" ]; then
    echo "======================================================================================================"
    echo "mcpv2日志如下"
    docker logs --tail=100 mcpv2
  elif [ "${HOST_ARCH}" = "aarch64" ]; then
    echo "======================================================================================================"
    echo "mcpv2日志如下"
    docker logs --tail=100 mcpv2scar
    echo "======================================================================================================"
    docker logs --tail=100 mcpv2
  else
      echo "不支持的架构: ${HOST_ARCH}"
      exit 1
  fi
}
echo && echo -e " 分享小鸡@mjjcloudplatform ${Red_font_prefix}[v0.5]${Font_color_suffix}
  -- v0.5 2024.9.3 -- 
  
  
————————————
 ${Green_font_prefix}0.${Font_color_suffix} Docker版安装&对接
 ${Green_font_prefix}1.${Font_color_suffix} 更新geo文件
————————————
 ${Green_font_prefix}2.${Font_color_suffix} 重启mcpv2
 ${Green_font_prefix}3.${Font_color_suffix} 停止mcpv2
 ${Green_font_prefix}4.${Font_color_suffix} 查看日志
 ${Green_font_prefix}5.${Font_color_suffix} 重启docker
————————————
 ${Green_font_prefix}9.${Font_color_suffix} 更换端口
————————————
 ${Green_font_prefix}88.${Font_color_suffix} 卸载
————————————
" && echo
read -e -p " 请输入数字:" num
case "$num" in
        0)
        update_geo
        installV2Ray
        showLog
        ;;
        1)
        update_geo
        updateCompose
        showLog
        ;;
        2)
        restartV2ray
        showLog
        ;;
        3)
        stopV2ray
        ;;
        4)
        showLog
        ;;
        9)
        refreshPort
        restartV2ray
        showLog
        ;;
        88)
        remove
        ;;
        *)
        echo "请输入正确数字 [0-4]"
        ;;
esac
