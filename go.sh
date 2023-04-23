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

CUR_VER=""
NEW_VER="v4.26.0"
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

downloadV2Ray(){
    rm -rf /tmp/v2ray
    mkdir -p /tmp/v2ray
    DOWNLOAD_LINK="https://github.com/v2fly/v2ray-core/releases/download/v4.26.0/v2ray-linux-64.zip"
    colorEcho ${BLUE} "Downloading V2Ray: ${DOWNLOAD_LINK}"
    wget -P /tmp/v2ray "https://github.com/jackma778/sh/releases/download/v0.1/v2scar"
    curl ${PROXY} -L -H "Cache-Control: no-cache" -o ${ZIPFILE} ${DOWNLOAD_LINK} 
    if [ $? != 0 ];then
        colorEcho ${RED} "Failed to download! Please check your network or try again."
        return 3
    fi
    return 0
}

installSoftware(){
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
    colorEcho ${BLUE} "Starting up V2Ray service."
	${SYSTEMCTL_CMD} restart v2ray && ${SYSTEMCTL_CMD} restart v2scar
    if [[ $? -ne 0 ]]; then
        colorEcho ${YELLOW} "Failed to start V2Ray service."
        return 2
    fi
    return 0
}

installV2Ray(){
  api=https://api.cjy.me
  token=MJJ6688
echo "https://share.cjy.me/ 登录后点击 共享节点  ："
echo "添加一个节点，输入节点信息并提交后，再继续操作本脚本"
echo "请输入节点id（和在上方链接内填写的nodeid保持一致）："
read new_nodeid

echo "请确认您要将nodeid设置为$new_nodeid(y/n)"
read confirm

if [ "$confirm" == "y" ] || [ "$confirm" == "Y" ]; then
  nodeId=$new_nodeid
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
    # Install V2Ray binary to /usr/bin/v2ray
    mkdir -p '/etc/v2ray' '/var/log/v2ray' && \
    unzip -oj "$1" "$2v2ray" "$2v2ctl" "$2geoip.dat" "$2geosite.dat" -d '/usr/bin/v2ray' && \
    mv /tmp/v2ray/v2scar /usr/bin/v2ray/ 
    chmod +x '/usr/bin/v2ray/v2scar' '/usr/bin/v2ray/v2ray' '/usr/bin/v2ray/v2ctl' || {
        colorEcho ${RED} "Failed to copy V2Ray binary and resources."
        return 1
    }

    # Install V2Ray.service and v2scar.service
    if [[ -n "${SYSTEMCTL_CMD}" ]]; then
		unzip -oj "$1" "$2systemd/v2ray.service" -d '/etc/systemd/system' && sed -i "s@ExecStart=.*@ExecStart=/usr/bin/v2ray/v2ray -config $api/api/vmess_server_config/$nodeId/?token=$token@" /etc/systemd/system/v2ray.service
		cat <<EOF > /etc/systemd/system/v2scar.service
[Unit]
Description=v2scar
[Service]
ExecStart=/usr/bin/v2ray/v2scar --nodeid=$nodeId
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF
		systemctl daemon-reload && systemctl enable v2ray.service && systemctl enable v2scar.service && systemctl start v2ray.service && systemctl start v2scar.service
	else
		echo "没有找到systemctl命令 无法配置启动脚本 请检查您的系统版本是否过老 建议使用debian10 64位"
    fi
else
  echo "取消安装"
fi
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

echo && echo -e " 分享小鸡@share_life_mjj ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  -- v0.1 2023.4.8 -- 
  
  
————————————
 ${Green_font_prefix}0.${Font_color_suffix} 安装&对接
————————————
 ${Green_font_prefix}1.${Font_color_suffix} 启动/重启
 ${Green_font_prefix}2.${Font_color_suffix} 停止
————————————
 ${Green_font_prefix}4.${Font_color_suffix} 卸载
————————————
" && echo
read -e -p " 请输入数字:" num
case "$num" in
        0)
	installSoftware curl
	installSoftware wget
	installSoftware unzip
	downloadV2Ray
	installV2Ray "${ZIPFILE}" "${ZIPROOT}" || return $?
        ;;
        1)
	restartV2ray
        ;;
        2)
	stopV2ray
        ;;
        4)
	remove
	    ;;
        *)
	echo "请输入正确数字 [0-6]"
	;;
esac
