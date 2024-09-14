#!/bin/bash
# This file is accessible as https://install.direct/go.sh
# Original source is located at github.com/v2fly/v2ray-core/release/install-release.sh

# If not specify, default meaning of return value:
# 0: Success
# 1: System error
# 2: Application error
# 3: Network error

# CLI arguments
PROXY=''
HELP=''
FORCE=''
CHECK=''
REMOVE=''
VERSION=''
VSRC_ROOT='/tmp/v2ray'
EXTRACT_ONLY=''
LOCAL=''
LOCAL_INSTALL=''
DIST_SRC='github'
ERROR_IF_UPTODATE=''
API='https://api.cjy.me'

CUR_VER=""
NEW_VER="v4.45.2"
ARCH=$(uname -m)
if [[ $ARCH == "armv7"* ]]; then
    DOWNLOAD_LINK="https://github.com/v2fly/v2ray-core/releases/download/${NEW_VER}/v2ray-linux-arm32-v7a.zip"
elif [[ $ARCH == "aarch64" ]]; then
    DOWNLOAD_LINK="https://github.com/v2fly/v2ray-core/releases/download/${NEW_VER}/v2ray-linux-arm64-v8a.zip"
elif [[ $ARCH == "x86_64" ]]; then
    DOWNLOAD_LINK="https://github.com/v2fly/v2ray-core/releases/download/${NEW_VER}/v2ray-linux-64.zip"
fi
VDIS=''
ZIPFILE="/tmp/v2ray/v2ray.zip"
V2RAY_RUNNING=0

CMD_INSTALL=""
CMD_UPDATE=""
SOFTWARE_UPDATED=0

SYSTEMCTL_CMD=$(command -v systemctl 2>/dev/null)
SERVICE_CMD=$(command -v service 2>/dev/null)

#######color code########
RED="31m"      # Error message
GREEN="32m"    # Success message
YELLOW="33m"   # Warning message
BLUE="36m"     # Info message


#########################
while [[ $# > 0 ]]; do
    case "$1" in
        -p|--proxy)
        PROXY="-x ${2}"
        shift # past argument
        ;;
        -h|--help)
        HELP="1"
        ;;
        -f|--force)
        FORCE="1"
        ;;
        -c|--check)
        CHECK="1"
        ;;
        --remove)
        REMOVE="1"
        ;;
        --version)
        VERSION="$2"
        shift
        ;;
        --extract)
        VSRC_ROOT="$2"
        shift
        ;;
        --extractonly)
        EXTRACT_ONLY="1"
        ;;
        -l|--local)
        LOCAL="$2"
        LOCAL_INSTALL="1"
        shift
        ;;
        --source)
        DIST_SRC="$2"
        shift
        ;;
        --errifuptodate)
        ERROR_IF_UPTODATE="1"
        ;;
        *)
                # unknown option
        ;;
    esac
    shift # past argument or value
done

###############################
colorEcho(){
    echo -e "\033[${1}${@:2}\033[0m" 1>& 2
}

archAffix(){
    case "${1:-"$(uname -m)"}" in
        i686|i386)
            echo '32'
        ;;
        x86_64|amd64)
            echo '64'
        ;;
        *armv7*|armv6l)
            echo 'arm'
        ;;
        *armv8*|aarch64)
            echo 'arm64'
        ;;
        *mips64le*)
            echo 'mips64le'
        ;;
        *mips64*)
            echo 'mips64'
        ;;
        *mipsle*)
            echo 'mipsle'
        ;;
        *mips*)
            echo 'mips'
        ;;
        *s390x*)
            echo 's390x'
        ;;
        ppc64le)
            echo 'ppc64le'
        ;;
        ppc64)
            echo 'ppc64'
        ;;
        *)
            return 1
        ;;
    esac

        return 0
}

zipRoot() {
    unzip -lqq "$1" | awk -e '
        NR == 1 {
            prefix = $4;
        }
        NR != 1 {
            prefix_len = length(prefix);
            cur_len = length($4);

            for (len = prefix_len < cur_len ? prefix_len : cur_len; len >= 1; len -= 1) {
                sub_prefix = substr(prefix, 1, len);
                sub_cur = substr($4, 1, len);

                if (sub_prefix == sub_cur) {
                    prefix = sub_prefix;
                    break;
                }
            }

            if (len == 0) {
                prefix = "";
                nextfile;
            }
        }
        END {
            print prefix;
        }
    '
}

installSoftware(){
    if [ "$(id -u)" -ne "0" ]; then
        colorEcho ${RED} "使用 root 执行此脚本。" >&2
        exit 1
    fi
    if [ -f /etc/systemd/system/v2scar.service ]; then
        colorEcho ${RED} "检测到mcp已安装，如需重装请先执行卸载。"
        exit 0
    fi
    COMPONENT=$1
    if [[ -n `command -v $COMPONENT` ]]; then
        return 0
    fi

    getPMT
    if [[ $? -eq 1 ]]; then
        colorEcho ${RED} "The system package manager tool isn't APT or YUM, please install ${COMPONENT} manually."
        return 1
    fi
    if [[ $SOFTWARE_UPDATED -eq 0 ]]; then
        colorEcho ${BLUE} "Updating software repo"
        $CMD_UPDATE
        SOFTWARE_UPDATED=1
    fi

    colorEcho ${BLUE} "Installing ${COMPONENT}"
    $CMD_INSTALL $COMPONENT
    if [[ $? -ne 0 ]]; then
        colorEcho ${RED} "Failed to install ${COMPONENT}. Please install it manually."
        return 1
    fi
    return 0
}

# return 1: not apt, yum, or zypper
getPMT(){
    if [[ -n `command -v apt-get` ]];then
        CMD_INSTALL="apt-get -y -qq install"
        CMD_UPDATE="apt update -y"
    elif [[ -n `command -v yum` ]]; then
        CMD_INSTALL="yum -y -q install"
        CMD_UPDATE="yum -q makecache"
    elif [[ -n `command -v zypper` ]]; then
        CMD_INSTALL="zypper -y install"
        CMD_UPDATE="zypper ref"
    else
        return 1
    fi
    return 0
}
refreshPort(){
    if [ ! -f /etc/systemd/system/v2scar.service ]; then
        colorEcho ${RED} "未检测到mcp服务端，请先安装"
        exit 0
    fi
    new_nodeid=`grep -oP '(?<=--nodeid=)\d+' /etc/systemd/system/v2scar.service`
    new_token=$(grep "^$new_nodeid=" /root/.mcptoken | cut -d '=' -f 2)
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
    refresh_port=$(curl -s "$API/api/refresh_server_port?token=$new_token&id=$new_nodeid&port=$new_port")
            if [[ $refresh_port =~ ^newPort= ]]; then
                    new_port=$(echo $refresh_port | cut -d '=' -f 2)
                    colorEcho ${GREEN} "端口更换成功，新端口为：$new_port"
            else
                    colorEcho ${RED} "端口更换失败，失败原因为：$refresh_port"
                    exit 1
            fi
}

installV2Ray(){
    colorEcho ${GREEN} "请先在网页添加主机信息后，再继续操作本脚本" 
    while true; do
            colorEcho ${BLUE} "请输入主机识别ID："
            read new_nodeid

            # 检查输入是否是数字
            if [[ "$new_nodeid" =~ ^[0-9]+$ ]]; then
                    break
            else
                    colorEcho ${RED} "主机识别ID是一个数字，请确认"
            fi
    done

    if [ ! -f /root/.mcptoken ]; then
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

    # Download V2ray
    rm -rf /tmp/v2ray
    mkdir -p /tmp/v2ray
    colorEcho ${BLUE} "Downloading V2Ray: ${DOWNLOAD_LINK}"
    
    if [[ $(uname -m) == "arm"* ]]; then
        wget --no-check-certificate -P /tmp/v2ray "https://github.com/jackma778/sh/releases/download/v0.1/v2scar_armlinux"
        mv /tmp/v2ray/v2scar_armlinux /tmp/v2ray/v2scar
    elif [[ $(uname -m) == "aarch64" ]]; then
        wget --no-check-certificate -P /tmp/v2ray "https://github.com/jackma778/sh/releases/download/v0.1/v2scar_armlinux"
        mv /tmp/v2ray/v2scar_armlinux /tmp/v2ray/v2scar
    else
        wget --no-check-certificate -P /tmp/v2ray "https://github.com/jackma778/sh/releases/download/v0.1/v2scar"
    fi
    
    if [ $? != 0 ]; then
        colorEcho ${RED} "Failed to download V2Ray! Please check your network or try again."
        return 3
    fi

    curl ${PROXY} -L -H "Cache-Control: no-cache" -o ${ZIPFILE} ${DOWNLOAD_LINK} 
    if [ $? != 0 ]; then
        colorEcho ${RED} "Failed to download V2Ray! Please check your network or try again."
        return 3
    fi

    # Install V2Ray binary to /usr/bin/v2ray
    mkdir -p '/etc/v2ray' '/var/log/v2ray' && unzip -oj "$1" "$2v2ray" "$2v2ctl" "$2geoip.dat" "$2geosite.dat" -d '/usr/bin/v2ray' && mv /tmp/v2ray/v2scar /usr/bin/v2ray/ && chmod +x '/usr/bin/v2ray/v2scar' '/usr/bin/v2ray/v2ray' '/usr/bin/v2ray/v2ctl' || {
        colorEcho ${RED} "Failed to copy V2Ray binary and resources."
        return 1
    }

    # Install V2Ray.service and v2scar.service
    if [[ -n "${SYSTEMCTL_CMD}" ]]; then
        cat <<EOF > /etc/systemd/system/v2ray.service
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target
Requires=v2scar.service
BindsTo=v2scar.service

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/bin/v2ray/v2ray -config $API/api/get_server_config?token=$new_token&id=$new_nodeid&docker=0
Restart=always
RestartSec=60s

[Install]
WantedBy=multi-user.target
EOF
        cat <<EOF > /etc/systemd/system/v2scar.service
[Unit]
Description=v2scar
After=v2ray.service
Requires=v2ray.service
BindsTo=v2ray.service

[Service]
ExecStart=/usr/bin/v2ray/v2scar --nodeid=$new_nodeid
Restart=always
RestartSec=60s
User=root
[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable v2ray.service
        systemctl enable v2scar.service
        colorEcho ${GREEN} "Install successfully."
        if crontab -l |grep -v docker| grep -q "v2scar"; then
            echo "pass"
        else
            echo "add crontab"
            minute=$(shuf -i 0-59 -n 1)
            hour=$(shuf -i 0-23 -n 1)
            weekday=$(shuf -i 0-6 -n 1)
            (crontab -l ; echo "$minute $hour * * $weekday systemctl restart v2ray && systemctl restart v2scar") | crontab -
        fi
    else
        colorEcho ${RED} "Failed to remove V2Ray, Try use debian10 64"
        return 2
    fi

}

stopV2ray(){
    colorEcho ${BLUE} "Shutting down V2Ray service."
    ${SYSTEMCTL_CMD} stop v2ray && ${SYSTEMCTL_CMD} stop v2scar
    if [[ $? -ne 0 ]]; then
        colorEcho ${YELLOW} "Failed to shutdown V2Ray service."
        return 2
    fi
    return 0
}

restartV2ray(){
    colorEcho ${BLUE} "Stop V2Ray service."
    systemctl stop v2ray.service && systemctl stop v2scar.service && colorEcho ${GREEN} "OK" || colorEcho ${RED} "FAILED"
    sleep 1
    colorEcho ${BLUE} "Starting up V2Ray service."
    ntpdate time.windows.com && hwclock -w
    systemctl start v2ray.service && systemctl start v2scar.service
    sleep 3
    ps -ef | grep v2ray| grep get_server_config
    if [ $? -eq 0 ];then
        colorEcho ${GREEN} "OK" 
    else
        showLog
        colorEcho ${RED} "FAILED"
    fi
}

showLog(){
    echo "======================================================================================================"
    echo "v2scar日志如下"
    journalctl -u v2scar.service -n 20 --no-pager
    echo "======================================================================================================"
    echo "v2ray日志如下"
    journalctl -u v2ray.service -n 25 --no-pager
    echo "======================================================================================================"
}



remove(){
        systemctl stop v2ray.service
        systemctl stop v2scar.service
        systemctl disable v2ray.service
        systemctl disable v2scar.service
        rm -rf "/etc/systemd/system/v2ray.service" "/etc/systemd/system/v2scar.service"
        if [[ $? -ne 0 ]]; then
            colorEcho ${RED} "Failed to remove V2Ray."
            return 0
        else
            colorEcho ${GREEN} "Removed V2Ray successfully."
            colorEcho ${BLUE} "If necessary, please remove configuration file and log file manually."
            return 0
        fi
}

update_geo(){
        DAT_PATH="/usr/bin/v2ray"
        DOWNLOAD_LINK_GEOIP="https://github.com/v2fly/geoip/releases/latest/download/geoip.dat"
        DOWNLOAD_LINK_GEOSITE="https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat"
        wget --no-check-certificate -O "${DAT_PATH}/geoip.dat" "${DOWNLOAD_LINK_GEOIP}"
        wget --no-check-certificate -O "${DAT_PATH}/geosite.dat" "${DOWNLOAD_LINK_GEOSITE}"
        chmod 644 "${DAT_PATH}"/*.dat
}



echo && echo -e " 分享小鸡@mjjcloudplatform ${Red_font_prefix}[v0.5]${Font_color_suffix}
  -- v0.5 2024.9.3 -- 
  
  
————————————
 ${Green_font_prefix}0.${Font_color_suffix} 安装&对接
 ${Green_font_prefix}1.${Font_color_suffix} 更新geo文件
————————————
 ${Green_font_prefix}2.${Font_color_suffix} 启动/重启
 ${Green_font_prefix}3.${Font_color_suffix} 停止
 ${Green_font_prefix}4.${Font_color_suffix} 查看日志
————————————
 ${Green_font_prefix}9.${Font_color_suffix} 更换端口
————————————
 ${Green_font_prefix}88.${Font_color_suffix} 卸载
————————————
" && echo
read -e -p " 请输入数字:" num
case "$num" in
        0)
        installSoftware curl
        installSoftware wget
        installSoftware unzip
        installSoftware ca-certificates
        installSoftware ntpdate
        installV2Ray "${ZIPFILE}" "${ZIPROOT}" || return $?
        update_geo
        restartV2ray
        ;;
        1)
        stopV2ray
        update_geo
        restartV2ray
        ;;
        2)
        restartV2ray
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
        ;;
        88)
        remove
            ;;
        *)
        echo "请输入正确数字 [0-4]"
        ;;
esac
