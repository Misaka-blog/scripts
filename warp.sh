#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove")

[[ $EUID -ne 0 ]] && red "注意：请在root用户下运行脚本" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i"
    if [[ -n $SYS ]]; then
        break
    fi
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}"
        if [[ -n $SYSTEM ]]; then
            break
        fi
    fi
done

[[ -z $SYSTEM ]] && red "不支持当前VPS系统, 请使用主流的操作系统" && exit 1

main=$(uname -r | awk -F . '{print $1}')
minor=$(uname -r | awk -F . '{print $2}')
OSID=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
VIRT=$(systemd-detect-virt)
TUN=$(cat /dev/net/tun 2>&1 | tr '[:upper:]' '[:lower:]')

wg1="sed -i '/0\.0\.0\.0\/0/d' /etc/wireguard/wgcf.conf"
wg2="sed -i '/\:\:\/0/d' /etc/wireguard/wgcf.conf"
# Wgcf Endpoint
wg3="sed -i 's/engage.cloudflareclient.com/162.159.193.10/g' /etc/wireguard/wgcf.conf"
wg4="sed -i 's/engage.cloudflareclient.com/[2606:4700:d0::a29f:c001]/g' /etc/wireguard/wgcf.conf"
# Wgcf DNS Servers
wg5="sed -i 's/1.1.1.1/1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4,2606:4700:4700::1111,2606:4700:4700::1001,2001:4860:4860::8888,2001:4860:4860::8844/g' /etc/wireguard/wgcf.conf"
wg6="sed -i 's/1.1.1.1/2606:4700:4700::1111,2606:4700:4700::1001,2001:4860:4860::8888,2001:4860:4860::8844,1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4/g' /etc/wireguard/wgcf.conf"
# Wgcf 允许外部IP地址
wg7='sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf'
wg8='sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf'
wg9='sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf'

wgo1='sed -i "s#.*AllowedIPs.*#AllowedIPs = 0.0.0.0/0#g" /opt/warp-go/warp.conf'
wgo2='sed -i "s#.*AllowedIPs.*#AllowedIPs = ::/0#g" /opt/warp-go/warp.conf'
wgo3='sed -i "s#.*AllowedIPs.*#AllowedIPs = 0.0.0.0/0,::/0#g" /opt/warp-go/warp.conf'
# WARP-Go EndPoint
wgo4='sed -i "/Endpoint6/d" /opt/warp-go/warp.conf && sed -i "s/162.159.*/162.159.193.10:1701/g" /opt/warp-go/warp.conf'
wgo5='sed -i "/Endpoint6/d" /opt/warp-go/warp.conf && sed -i "s/162.159.*/[2606:4700:d0::a29f:c003]:1701/g" /opt/warp-go/warp.conf'
# WARP-Go 允许外部IP地址
wgo6='sed -i "s#.*PostUp.*#PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main#g;s#.*PostDown.*#PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main#g" /opt/warp-go/warp.conf'
wgo7='sed -i "s#.*PostUp.*#PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main#g;s#.*PostDown.*#PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main#g" /opt/warp-go/warp.conf'
wgo8='sed -i "s#.*PostUp.*#PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main; ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main#g;s#.*PostDown.*#PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main; ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main#g" /opt/warp-go/warp.conf'

if [[ -z $(type -P curl) ]]; then
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} curl
fi

archAffix(){
    case "$(uname -m)" in
        x86_64 | amd64 ) echo 'amd64' ;;
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        s390x ) echo 's390x' ;;
        * ) red "不支持的CPU架构!" && exit 1 ;;
    esac
}

if [[ ! -f /usr/local/bin/nf ]]; then
    wget https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/netflix-verify/nf-linux-$(archAffix) -O /usr/local/bin/nf
    chmod +x /usr/local/bin/nf
fi

checkv4v6(){
    ipv4=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p)
    ipv6=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)
}

checkwarp(){
    wpv4=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    wpv6=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
}

checkmtu(){
    yellow "正在检测并设置MTU最佳值, 请稍等..."
    checkv4v6
    MTUy=1500
    MTUc=10
    if [[ -n ${v6} && -z ${v4} ]]; then
        ping='ping6'
        IP1='2606:4700:4700::1001'
        IP2='2001:4860:4860::8888'
    else
        ping='ping'
        IP1='1.1.1.1'
        IP2='8.8.8.8'
    fi
    while true; do
        if ${ping} -c1 -W1 -s$((${MTUy} - 28)) -Mdo ${IP1} >/dev/null 2>&1 || ${ping} -c1 -W1 -s$((${MTUy} - 28)) -Mdo ${IP2} >/dev/null 2>&1; then
            MTUc=1
            MTUy=$((${MTUy} + ${MTUc}))
        else
            MTUy=$((${MTUy} - ${MTUc}))
            if [[ ${MTUc} = 1 ]]; then
                break
            fi
        fi
        if [[ ${MTUy} -le 1360 ]]; then
            MTUy='1360'
            break
        fi
    done
    MTU=$((${MTUy} - 80))
    sed -i "s/MTU.*/MTU = $MTU/g" wgcf-profile.conf
    green "MTU 最佳值=$MTU 已设置完毕"
}

checkstack(){
    lan4=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
    lan6=$(ip route get 2606:4700:4700::1111 2>/dev/null | grep -oP 'src \K\S+')
    if [[ "$lan4" =~ ^([0-9]{1,3}\.){3} ]]; then
        ping -c2 -W3 1.1.1.1 >/dev/null 2>&1 && out4=1
    fi
    if [[ "$lan6" != "::1" && "$lan6" =~ ^([a-f0-9]{1,4}:){2,4}[a-f0-9]{1,4} ]]; then
        ping6 -c2 -w10 2606:4700:4700::1111 >/dev/null 2>&1 && out6=1
    fi
}

check_quota(){
    if [[ "$CHECK_TYPE" = 1 ]]; then
        QUOTA=$(warp-cli --accept-tos account 2>/dev/null | grep -oP 'Quota: \K\d+')
    else
        if [[ -a "/opt/warp-go/warp-go" ]]; then
            ACCESS_TOKEN=$(grep 'Token' /opt/warp-go/warp.conf | cut -d= -f2 | sed 's# ##g')
            DEVICE_ID=$(grep 'Device' /opt/warp-go/warp.conf | cut -d= -f2 | sed 's# ##g')
        fi
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            ACCESS_TOKEN=$(grep 'access_token' /etc/wireguard/wgcf-account.toml | cut -d \' -f2)
            DEVICE_ID=$(grep 'device_id' /etc/wireguard/wgcf-account.toml | cut -d \' -f2)
        fi
        API=$(curl -s "https://api.cloudflareclient.com/v0a884/reg/$DEVICE_ID" -H "User-Agent: okhttp/3.12.1" -H "Authorization: Bearer $ACCESS_TOKEN")
        QUOTA=$(grep -oP '"quota":\K\d+' <<< $API)
    fi
    [[ $QUOTA -gt 10000000000000 ]] && QUOTA="$(echo "scale=2; $QUOTA/1000000000000" | bc) TB" || QUOTA="$(echo "scale=2; $QUOTA/1000000000" | bc) GB"
}

checktun(){
    if [[ ! $TUN =~ "in bad state"|"处于错误状态"|"ist in schlechter Verfassung" ]]; then
        if [[ $VIRT == lxc ]]; then
            if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]]; then
                red "检测到目前VPS未开启TUN模块, 请到后台控制面板处开启"
                exit 1
            else
                return 0
            fi
        elif [[ $VIRT == "openvz" ]]; then
            wget -N --no-check-certificate https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/tun.sh && bash tun.sh
        else
            red "检测到目前VPS未开启TUN模块, 请到后台控制面板处开启"
            exit 1
        fi
    fi
}

infowgcf(){
    echo ""
    yellow "请选择你需要安装 / 切换的模式："
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 / 切换 Wgcf-WARP 单栈模式 ${YELLOW}(IPv4)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 安装 / 切换 Wgcf-WARP 单栈模式 ${YELLOW}(IPv6)${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} 安装 / 切换 Wgcf-WARP 双栈模式"
    echo ""
    read -rp "请输入选项 [0-3]: " wgcfInfoInput
    case $wgcfInfoInput in
        1 ) wgcfinfo=1 && readywgcfconf ;;
        2 ) wgcfinfo=2 && readywgcfconf ;;
        3 ) wgcfinfo=3 && readywgcfconf ;;
        * ) exit 1 ;;
    esac
}

readywgcfconf(){
    checkwarp

    if [[ -a "/opt/warp-go/warp-go" ]]; then
        red "检测到您已经安装了WARP-GO，请先卸载WARP-GO后再安装Wgcf-WARP！"
        exit 1
    fi

    if [[ $wpv4 =~ on|plus ]] || [[ $wpv6 =~ on|plus ]]; then
        stopwgcf
    fi
    checkstack

    if [[ $wgcfinfo == 1 ]]; then
        if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                yellow "检测为纯IPv4的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv4)"
                stopwgcf && switchconf
                wgcf1=$wg5 && wgcf2=$wg7 && wgcf3=$wg2 && wgcf4=$wg3
                wgcfconf && wgcfcheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为纯IPv4的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv4)"
                wgcf1=$wg5 && wgcf2=$wg7 && wgcf3=$wg2 && wgcf4=$wg3
                installwgcf
            fi
        elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                yellow "检测为纯IPv6的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
                stopwgcf && switchconf
                wgcf1=$wg6 && wgcf2=$wg2 && wgcf3=$wg4
                wgcfconf && wgcfcheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为纯IPv6的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
                wgcf1=$wg6 && wgcf2=$wg2 && wgcf3=$wg4
                installwgcf
            fi
        elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                yellow "检测为原生双栈的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
                stopwgcf && switchconf
                wgcf1=$wg5 && wgcf2=$wg7 && wgcf3=$wg2
                wgcfconf && wgcfcheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为原生双栈的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
                wgcf1=$wg5 && wgcf2=$wg7 && wgcf3=$wg2
                installwgcf
            fi
        elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                yellow "检测为NAT IPv4+原生 IPv6的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
                stopwgcf && switchconf
                wgcf1=$wg6 && wgcf2=$wg7 && wgcf3=$wg2 && wgcf4=$wg4
                wgcfconf && wgcfcheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为NAT IPv4+原生IPv6的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv4 + 原生 IPv6)"
                wgcf1=$wg6 && wgcf2=$wg7 && wgcf3=$wg2 && wgcf4=$wg4
                installwgcf
            fi
        fi
    fi
    if [[ $wgcfinfo == 2 ]]; then
        if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                yellow "检测为纯IPv4的VPS，正在切换为Wgcf-WARP全局单栈模式 (原生IPv4 + WARP IPv6)"
                stopwgcf && switchconf
                wgcf1=$wg5 && wgcf2=$wg1 && wgcf3=$wg3
                wgcfconf && wgcfcheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为纯IPv4的VPS，正在安装Wgcf-WARP全局单栈模式 (原生IPv4 + WARP IPv6)"
                wgcf1=$wg5 && wgcf2=$wg1 && wgcf3=$wg3
                installwgcf
            fi
        elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                yellow "检测为纯IPv6的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv6)"
                stopwgcf && switchconf
                wgcf1=$wg6 && wgcf2=$wg8 && wgcf3=$wg1 && wgcf4=$wg4
                wgcfconf && wgcfcheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为纯IPv6的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv6)"
                wgcf1=$wg6 && wgcf2=$wg8 && wgcf3=$wg1 && wgcf4=$wg4
                installwgcf
            fi
        elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                yellow "检测为原生双栈的VPS，正在切换为Wgcf-WARP全局单栈模式 (原生 IPv4 + WARP IPv6)"
                stopwgcf && switchconf
                wgcf1=$wg5 && wgcf2=$wg8 && wgcf3=$wg1
                wgcfconf && wgcfcheck && checkv4v6 && checkwarp && ipinfo             
            else
                yellow "检测为原生双栈的VPS，正在安装Wgcf-WARP全局单栈模式 (原生 IPv4 + WARP IPv6)"
                wgcf1=$wg5 && wgcf2=$wg8 && wgcf3=$wg1
                installwgcf
            fi
        elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                yellow "检测为NAT IPv4+原生 IPv6的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv6)"
                stopwgcf && switchconf
                wgcf1=$wg6 && wgcf2=$wg9 && wgcf3=$wg1 && wgcf4=$wg4
                wgcfconf && wgcfcheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为NAT IPv4+原生 IPv6的VPS，正在安装Wgcf-WARP全局单栈模式 (WARP IPv6)"
                wgcf1=$wg6 && wgcf2=$wg9 && wgcf3=$wg1 && wgcf4=$wg4
                installwgcf
            fi
        fi
    fi
    if [[ $wgcfinfo == 3 ]]; then
        if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                yellow "检测为纯IPv4的VPS，正在切换为Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
                stopwgcf && switchconf
                wgcf1=$wg5 && wgcf2=$wg7 && wgcf3=$wg3
                wgcfconf && wgcfcheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为纯IPv4的VPS，正在安装Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
                wgcf1=$wg5 && wgcf2=$wg7 && wgcf3=$wg3
                installwgcf
            fi
        elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                yellow "检测为纯IPv6的VPS，正在切换为Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
                stopwgcf && switchconf
                wgcf1=$wg6 && wgcf2=$wg8 && wgcf3=$wg4
                wgcfconf && wgcfcheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为纯IPv6的VPS，正在安装Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
                wgcf1=$wg6 && wgcf2=$wg8 && wgcf3=$wg4
                installwgcf
            fi
        elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                yellow "检测为原生双栈的VPS，正在切换为Wgcf-WARP全局单栈模式 (WARP IPv4 + WARP IPv6)"
                stopwgcf && switchconf
                wgcf1=$wg5 && wgcf2=$wg9
                wgcfconf && wgcfcheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为原生双栈的VPS，正在安装Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
                wgcf1=$wg5 && wgcf2=$wg9
                installwgcf
            fi
        elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                yellow "检测为NAT IPv4+原生 IPv6的VPS，正在切换为Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
                stopwgcf && switchconf
                wgcf1=$wg6 && wgcf2=$wg9 && wgcf3=$wg4
                wgcfconf && wgcfcheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为NAT IPv4+原生 IPv6的VPS，正在安装Wgcf-WARP全局双栈模式 (WARP IPv4 + WARP IPv6)"
                wgcf1=$wg6 && wgcf2=$wg9 && wgcf3=$wg4
                installwgcf
            fi
        fi
    fi
}

installwgcf(){
    [[ $SYSTEM == "CentOS" ]] && [[ ${OSID} -lt 7 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持CentOS / Almalinux / Rocky / Oracle Linux 7及以上版本的系统" && exit 1
    [[ $SYSTEM == "Debian" ]] && [[ ${OSID} -lt 10 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持Debian 10及以上版本的系统" && exit 1
    [[ $SYSTEM == "Fedora" ]] && [[ ${OSID} -lt 29 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持Fedora 29及以上版本的系统" && exit 1
    [[ $SYSTEM == "Ubuntu" ]] && [[ ${OSID} -lt 18 ]] && yellow "当前系统版本：${CMD} \nWgcf-WARP模式仅支持Ubuntu 16.04及以上版本的系统" && exit 1

    checktun

    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} epel-release
        ${PACKAGE_INSTALL[int]} sudo curl wget iproute net-tools wireguard-tools iptables bc htop screen python3 iputils qrencode
        if [[ $OSID == 9 ]] && [[ -z $(type -P resolvconf) ]]; then
            wget -N https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/resolvconf -O /usr/sbin/resolvconf
            chmod +x /usr/sbin/resolvconf
        fi
    fi
    if [[ $SYSTEM == "Fedora" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget iproute net-tools wireguard-tools iptables bc htop screen python3 iputils qrencode
    fi
    if [[ $SYSTEM == "Debian" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo wget curl lsb-release bc htop screen python3 inetutils-ping qrencode
        echo "deb http://deb.debian.org/debian $(lsb_release -sc)-backports main" | tee /etc/apt/sources.list.d/backports.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi
    if [[ $SYSTEM == "Ubuntu" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release bc htop screen python3 inetutils-ping qrencode
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi
    
    if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]] || [[ $VIRT =~ lxc|openvz ]]; then
        wget -N --no-check-certificate https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/wireguard-go/wireguard-go-$(archAffix) -O /usr/bin/wireguard-go
        chmod +x /usr/bin/wireguard-go
    fi

    initwgcf
    wgcfreg
    checkmtu

    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
    fi
    
    cp -f wgcf-profile.conf /etc/wireguard/wgcf.conf >/dev/null 2>&1
    mv -f wgcf-profile.conf /etc/wireguard/wgcf-profile.conf >/dev/null 2>&1
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml >/dev/null 2>&1

    wgcfconf

    systemctl enable wg-quick@wgcf >/dev/null 2>&1
    wgcfcheck
    checkv4v6
    checkwarp
    ipinfo
}

initwgcf(){
    wget -N --no-check-certificate https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/wgcf/wgcf-latest-linux-$(archAffix) -O /usr/local/bin/wgcf
    chmod +x /usr/local/bin/wgcf
}

wgcfreg(){
    if [[ -f /etc/wireguard/wgcf-account.toml ]]; then
        cp -f /etc/wireguard/wgcf-account.toml /root/wgcf-account.toml
    fi

    until [[ -a wgcf-account.toml ]]; do
        yellow "正在向CloudFlare WARP注册账号, 如提示429 Too Many Requests错误请耐心等待脚本重试注册即可"
        wgcf register --accept-tos
        sleep 5
    done
    chmod +x wgcf-account.toml

    wgcf generate
    chmod +x wgcf-profile.conf
}

switchconf(){
    rm -rf /etc/wireguard/wgcf.conf
    cp -f /etc/wireguard/wgcf-profile.conf /etc/wireguard/wgcf.conf >/dev/null 2>&1
}

wgcfconf(){
    echo $wgcf1 | sh
    echo $wgcf2 | sh
    echo $wgcf3 | sh
    echo $wgcf4 | sh
}

wgcfcheck(){
    yellow "正在启动 Wgcf-WARP"
    i=0
    while [ $i -le 4 ]; do let i++
        wg-quick down wgcf >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
        checkwarp
        if [[ $wpv4 =~ on|plus ]] || [[ $wpv6 =~ on|plus ]]; then
            green "Wgcf-WARP 已启动成功！"
            break
        else
            red "Wgcf-WARP 启动失败！"
        fi
        checkwarp
        if [[ ! $wpv4 =~ on|plus && ! $wpv6 =~ on|plus ]]; then
            wg-quick down wgcf >/dev/null 2>&1
            red "安装Wgcf-WARP失败！"
            green "建议如下："
            yellow "1. 强烈建议使用官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为官方源"
            yellow "2. 部分VPS系统极度精简，相关依赖需自行安装后再尝试"
            yellow "3. 查看https://www.cloudflarestatus.com/,你当前VPS就近区域可能处于黄色的【Re-routed】状态"
            exit 1
        fi
    done
}

startwgcf(){
    wg-quick up wgcf >/dev/null 2>&1
    systemctl enable wg-quick@wgcf >/dev/null 2>&1
}

stopwgcf(){
    wg-quick down wgcf >/dev/null 2>&1
    systemctl disable wg-quick@wgcf >/dev/null 2>&1
}

unstwgcf(){
    wg-quick down wgcf 2>/dev/null
    systemctl disable wg-quick@wgcf 2>/dev/null
    ${PACKAGE_UNINSTALL[int]} wireguard-tools wireguard-dkms
    if [[ -z $(type -P wireproxy) ]]; then
        rm -f /usr/local/bin/wgcf
        rm -f /etc/wireguard/wgcf-account.toml
    fi
    rm -f /etc/wireguard/wgcf.conf
    rm -f /usr/bin/wireguard-go
    if [[ -e /etc/gai.conf ]]; then
        sed -i '/^precedence[ ]*::ffff:0:0\/96[ ]*100/d' /etc/gai.conf
    fi
    green "Wgcf-WARP 已彻底卸载成功!"
}

infowpgo(){
    echo ""
    yellow "请选择你需要安装 / 切换的模式："
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 / 切换 WARP-GO 单栈模式 ${YELLOW}(IPv4)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 安装 / 切换 WARP-GO 单栈模式 ${YELLOW}(IPv6)${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} 安装 / 切换 WARP-GO 双栈模式"
    echo ""
    read -rp "请输入选项 [0-3]: " wpgoInfoInput
    case $wpgoInfoInput in
        1 ) wpgoinfo=1 && readywpgoconf ;;
        2 ) wpgoinfo=2 && readywpgoconf ;;
        3 ) wpgoinfo=3 && readywpgoconf ;;
        * ) exit 1 ;;
    esac
}

readywpgoconf(){
    checkwarp

    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        red "检测到您已经安装了Wgcf-WARP，请先卸载Wgcf-WARP后再安装Wgcf-WARP！"
        exit 1
    fi

    if [[ $wpv4 =~ on|plus ]] || [[ $wpv6 =~ on|plus ]]; then
        stopwpgo
    fi
    checkstack

    if [[ $wpgoinfo == 1 ]]; then
        if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                yellow "检测为纯IPv4的VPS，正在切换为WARP-Go全局单栈模式 (WARP IPv4)"
                stopwpgo
                wpgo1=$wgo1 && wpgo2=$wgo4 && wpgo3=$wgo6
                wpgoconf && wpgocheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为纯IPv4的VPS，正在安装WARP-Go全局单栈模式 (WARP IPv4)"
                wpgo1=$wgo1 && wpgo2=$wgo4 && wpgo3=$wgo6
                installwpgo
            fi
        elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                yellow "检测为纯IPv6的VPS，正在切换为WARP-Go全局单栈模式 (WARP IPv4 + 原生 IPv6)"
                stopwpgo
                wpgo1=$wgo1 && wpgo2=$wgo5 && wpgo3=$wgo7
                wpgoconf && wpgocheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为纯IPv6的VPS，正在安装WARP-Go全局单栈模式 (WARP IPv4 + 原生 IPv6)"
                wpgo1=$wgo1 && wpgo2=$wgo5 && wpgo3=$wgo7
                installwpgo
            fi
        elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                yellow "检测为原生双栈的VPS，正在切换为WARP-Go全局单栈模式 (WARP IPv4 + 原生 IPv6)"
                stopwpgo
                wpgo1=$wgo1 && wpgo2=$wgo4 && wpgo3=$wgo8
                wpgoconf && wpgocheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为原生双栈的VPS，正在安装WARP-Go全局单栈模式 (WARP IPv4 + 原生 IPv6)"
                wpgo1=$wgo1 && wpgo2=$wgo4 && wpgo3=$wgo8
                installwpgo
            fi
        elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                yellow "检测为NAT IPv4+原生IPv6的VPS，正在切换WARP-Go全局单栈模式 (WARP IPv4 + 原生 IPv6)"
                stopwpgo
                wpgo1=$wgo1 && wpgo2=$wgo5 && wpgo3=$wgo8
                wpgoconf && wpgocheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为NAT IPv4+原生IPv6的VPS，正在安装WARP-Go全局单栈模式 (WARP IPv4 + 原生 IPv6)"
                wpgo1=$wgo1 && wpgo2=$wgo5 && wpgo3=$wgo8
                installwpgo
            fi
        fi
    fi
    if [[ $wpgoinfo == 2 ]]; then
        if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                yellow "检测为纯IPv4的VPS，正在切换为WARP-Go全局单栈模式 (原生IPv4 + WARP IPv6)"
                stopwpgo
                wpgo1=$wgo2 && wpgo2=$wgo4 && wpgo3=$wgo6
                wpgoconf && wpgocheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为纯IPv4的VPS，正在安装为WARP-Go全局单栈模式 (原生IPv4 + WARP IPv6)"
                wpgo1=$wgo2 && wpgo2=$wgo4 && wpgo3=$wgo6
                installwpgo
            fi
        elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                yellow "检测为纯IPv6的VPS，正在切换为WARP-Go全局单栈模式 (WARP IPv6)"
                stopwpgo
                wpgo1=$wgo2 && wpgo2=$wgo5 && wpgo3=$wgo7
                wpgoconf && wpgocheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为纯IPv6的VPS，正在安装为WARP-Go全局单栈模式 (WARP IPv6)"
                wpgo1=$wgo2 && wpgo2=$wgo5 && wpgo3=$wgo7
                installwpgo
            fi
        elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                yellow "检测为原生双栈的VPS，正在切换WARP-Go全局单栈模式 (原生 IPv4 + WARP IPv6)"
                stopwpgo
                wpgo1=$wgo2 && wpgo2=$wgo4 && wpgo3=$wgo8
                wpgoconf && wpgocheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为原生双栈的VPS，正在安装WARP-Go全局单栈模式 (原生 IPv4 + WARP IPv6)"
                wpgo1=$wgo2 && wpgo2=$wgo4 && wpgo3=$wgo8
                installwpgo
            fi
        elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                yellow "检测为NAT IPv4+原生 IPv6的VPS，正在切换WARP-Go全局单栈模式 (WARP IPv6)"
                stopwpgo
                wpgo1=$wgo2 && wpgo2=$wgo5 && wpgo3=$wgo8
                wpgoconf && wpgocheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为NAT IPv4+原生 IPv6的VPS，正在安装WARP-Go全局单栈模式 (WARP IPv6)"
                wpgo1=$wgo2 && wpgo2=$wgo5 && wpgo3=$wgo8
                installwpgo
            fi
        fi
    fi
    if [[ $wpgoinfo == 3 ]]; then
        if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                yellow "检测为纯IPv4的VPS，正在切换为WARP-Go全局双栈模式 (WARP IPv4 + WARP IPv6)"
                stopwpgo
                wpgo1=$wgo3 && wpgo2=$wgo4 && wpgo3=$wgo6
                wpgoconf && wpgocheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为纯IPv4的VPS，正在安装为WARP-Go全局双栈模式 (WARP IPv4 + WARP IPv6)"
                wpgo1=$wgo3 && wpgo2=$wgo4 && wpgo3=$wgo6
                installwpgo
            fi
        elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                yellow "检测为纯IPv6的VPS，正在切换为WARP-Go全局双栈模式 (WARP IPv4 + WARP IPv6)"
                stopwpgo
                wpgo1=$wgo3 && wpgo2=$wgo5 && wpgo3=$wgo7
                wpgoconf && wpgocheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为纯IPv6的VPS，正在安装为WARP-Go全局双栈模式 (WARP IPv4 + WARP IPv6)"
                wpgo1=$wgo3 && wpgo2=$wgo5 && wpgo3=$wgo7
                installwpgo
            fi
        elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                yellow "检测为原生双栈的VPS，正在切换为WARP-Go全局双栈模式 (WARP IPv4 + WARP IPv6)"
                stopwpgo
                wpgo1=$wgo3 && wpgo2=$wgo4 && wpgo3=$wgo8
                wpgoconf && wpgocheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为原生双栈的VPS，正在安装为WARP-Go全局双栈模式 (WARP IPv4 + WARP IPv6)"
                wpgo1=$wgo3 && wpgo2=$wgo4 && wpgo3=$wgo8
                installwpgo
            fi
        elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
            if [[ -a "/opt/warp-go/warp-go" ]]; then
                yellow "检测为NAT IPv4+原生 IPv6的VPS，正在切换WARP-Go全局双栈模式 (WARP IPv4 + WARP IPv6)"
                stopwpgo
                wpgo1=$wgo3 && wpgo2=$wgo5 && wpgo3=$wgo8
                wpgoconf && wpgocheck && checkv4v6 && checkwarp && ipinfo
            else
                yellow "检测为NAT IPv4+原生 IPv6的VPS，正在安装WARP-Go全局双栈模式 (WARP IPv4 + WARP IPv6)"
                wpgo1=$wgo3 && wpgo2=$wgo5 && wpgo3=$wgo8
                installwpgo
            fi
        fi
    fi
}

installwpgo(){
    checktun

    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget bc htop iputils screen python3 qrencode
    else
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget bc htop inetutils-ping screen python3 qrencode
    fi

    mkdir -p /opt/warp-go/
    wget -O /opt/warp-go/warp-go https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-go/warp-go-latest-linux-$(archAffix)
    chmod +x /opt/warp-go/warp-go

    wpgoreg

    cat <<EOF > /lib/systemd/system/warp-go.service
[Unit]
Description=warp-go service
After=network.target
Documentation=https://github.com/Misaka-blog/cfwarp-script
Documentation=https://gitlab.com/ProjectWARP/warp-go
[Service]
WorkingDirectory=/opt/warp-go/
ExecStart=/opt/warp-go/warp-go --config=/opt/warp-go/warp.conf
Environment="LOG_LEVEL=verbose"
RemainAfterExit=yes
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    wpgoconf
    wpgocheck
    checkv4v6
    checkwarp
    ipinfo
}

wpgoreg(){
    until [[ -e /opt/warp-go/warp.conf ]]; do
        yellow "正在向CloudFlare WARP注册账号, 如出现Success即为注册成功"
        /opt/warp-go/warp-go --register --config=/opt/warp-go/warp.conf
    done
}

wpgoconf(){
    echo $wpgo1 | sh
    echo $wpgo2 | sh
    echo $wpgo3 | sh
}

wpgocheck(){
    yellow "正在启动 WARP-GO"
    i=0
    while [ $i -le 4 ]; do let i++
        systemctl stop warp-go
        systemctl disable warp-go >/dev/null 2>&1
        systemctl start warp-go
        systemctl enable warp-go >/dev/null 2>&1
        checkwarp
        sleep 5
        if [[ $wpv4 =~ on|plus ]] || [[ $wpv6 =~ on|plus ]]; then
            green "WARP-GO 已启动成功！"
            break
        else
            red "WARP-GO 启动失败！"
        fi
        checkwarp
        if [[ ! $wpv4 =~ on|plus && ! $wpv6 =~ on|plus ]]; then
            systemctl stop warp-go
            systemctl disable warp-go >/dev/null 2>&1
            red "安装WARP-GO失败！"
            green "建议如下："
            yellow "1. 强烈建议使用官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为官方源"
            yellow "2. 部分VPS系统极度精简，相关依赖需自行安装后再尝试"
            exit 1
        fi
    done
}

startwpgo(){
    systemctl start warp-go
    systemctl enable warp-go >/dev/null 2>&1
}

stopwpgo(){
    systemctl stop warp-go
    systemctl disable warp-go >/dev/null 2>&1
}

unstwpgo(){
    systemctl disable --now warp-go >/dev/null 2>&1
    kill -15 $(pgrep warp-go) >/dev/null 2>&1
    /opt/warp-go/warp-go --config=/opt/warp-go/warp.conf --remove >/dev/null 2>&1
    rm -rf /opt/warp-go /usr/bin/warp-go /lib/systemd/system/warp-go.service
    green "WARP-Go 已彻底卸载成功!"
}

warpswitch(){
    echo ""
    yellow "请选择你需要的操作："
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 启动 Wgcf-WARP"
    echo -e " ${GREEN}2.${PLAIN} 关闭 Wgcf-WARP"
    echo -e " ${GREEN}3.${PLAIN} 重启 Wgcf-WARP"
    echo -e " ${GREEN}4.${PLAIN} 启动 WARP-GO"
    echo -e " ${GREEN}5.${PLAIN} 关闭 WARP-GO"
    echo -e " ${GREEN}6.${PLAIN} 重启 WARP-GO"
    echo ""
    read -rp "请输入选项 [0-3]: " switchInput
    case $switchInput in
        1 ) startwgcf ;;
        2 ) stopwgcf ;;
        3 ) stopwgcf && startwgcf ;;
        4 ) startwpgo ;;
        5 ) stopwpgo ;;
        6 ) stopwpgo && startwpgo ;;
        * ) exit 1 ;;
    esac
}

warptraffic(){
    if [[ -z $(type -P screen) ]]; then
        if [[ ! $SYSTEM == "CentOS" ]]; then
            ${PACKAGE_UPDATE[int]}
        fi
        ${PACKAGE_INSTALL[int]} screen
    fi
    yellow "获取CloudFlare WARP账号信息方法: "
    green "电脑: 下载并安装CloudFlare WARP→设置→偏好设置→复制设备ID到脚本中"
    green "手机: 下载并安装1.1.1.1 APP→菜单→高级→诊断→复制设备ID到脚本中"
    echo ""
    yellow "请按照下面指示, 输入您的CloudFlare WARP账号信息:"
    read -rp "请输入您的WARP设备ID (36位字符): " license
    until [[ $license =~ ^[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}$ ]]; do
        red "设备ID输入格式输入错误，请重新输入！"
        read -rp "请输入您的WARP设备ID (36位字符): " license
    done
    wget -N --no-check-certificate https://raw.githubusercontent.com/Misaka-blog/cfwarp-script/main/files/wp-plus.py
    sed -i "27 s/[(][^)]*[)]//g" wp-plus.py
    sed -i "27 s/input/'$license'/" wp-plus.py
    read -rp "请输入Screen会话名称 (默认为wp-plus): " screenname
    [[ -z $screenname ]] && screenname="wp-plus"
    screen -UdmS $screenname bash -c '/usr/bin/python3 /root/wp-plus.py'
    green "创建刷WARP+流量任务成功！ Screen会话名称为：$screenname"
}

wgcfprofile(){
    yellow "请选择将要生成的配置文件的网络环境："
    green "1. IPv4 （默认）"
    green "2. IPv6"
    read -rp "请输入选项 [1-2]：" netInput
    case $netInput in
        1) endip="162.159.193.10" ;;
        2) endip="[2606:4700:d0::]" ;;
        *) endip="162.159.193.10" ;;
    esac
    cp -f /etc/wireguard/wgcf.conf /root/wgcf-proxy.conf
    sed -i '/PostUp/d;/PostDown/d;/AllowedIPs/d;/Endpoint/d' /root/wgcf-proxy.conf
    sed -i "8a AllowedIPs = 0.0.0.0\/0\nAllowedIPs = ::\/0\n" /root/wgcf-proxy.conf
    sed -i "10a Endpoint = $endip:2408" /root/wgcf-proxy.conf
    green "Wgcf-WARP的WireGuard配置文件已提取成功！"
    yellow "文件已保存至：/root/wgcf-proxy.conf"
    yellow "节点配置二维码如下所示："
    qrencode -t ansiutf8 < /root/wgcf-proxy.conf
}

wpgoprofile(){
    yellow "请选择将要生成的配置文件的网络环境："
    green "1. IPv4 （默认）"
    green "2. IPv6"
    read -rp "请输入选项 [1-2]：" netInput
    case $netInput in
        1) endip="162.159.193.10" ;;
        2) endip="[2606:4700:d0::]" ;;
        *) endip="162.159.193.10" ;;
    esac
    result=$(/opt/warp-go/warp-go --config=/opt/warp-go/warp.conf --export-wireguard=/root/warpgo-proxy.conf)
    sleep 2
    if [[ ! $result == "Success" ]]; then
        red "WARP-Go的WireGuard配置文件生成失败！"
        exit 1
    fi
    sed -i "s/engage.cloudflareclient.com/$endip/g" /root/warpgo-proxy.conf
    green "WARP-Go的WireGuard配置文件已提取成功！"
    yellow "文件已保存至：/root/warpgo-proxy.conf"
    yellow "节点配置二维码如下所示："
    qrencode -t ansiutf8 < /root/warpgo-proxy.conf
}

wgprofile(){
    yellow "请选择将要生成的配置文件的WARP客户端："
    green "1. Wgcf-WARP （默认）"
    green "2. WARP-Go"
    read -rp "请输入选项 [1-2]：" clientInput
    case $clientInput in
        2) wpgoprofile ;;
        *) wgcfprofile ;;
    esac
}

wgcfaccount(){
    yellow "请选择将要切换的WARP账户类型："
    green "1. WARP 免费版账户 （默认）"
    green "2. WARP+"
    green "3. WARP Teams"
    read -rp "请输入选项 [1-3]：" accountInput
    if [[ $accountInput == 1 ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        cd /etc/wireguard
        rm -f wgcf-account.toml wgcf-profile.conf
        wgcfreg
        warpPublicKey=$(grep PublicKey /etc/wireguard/wgcf-profile.conf | sed "s/PublicKey = //g")
        warpPrivateKey=$(grep PrivateKey /etc/wireguard/wgcf-profile.conf | sed "s/PrivateKey = //g")
        warpIPv4Address=$(cat /etc/wireguard/wgcf-profile.conf | sed -n 3p | sed "s/Address = //g")
        warpIPv6Address=$(cat /etc/wireguard/wgcf-profile.conf | sed -n 4p | sed "s/Address = //g")
        sed -i "s#PublicKey.*#PublicKey = $warpPublicKey#g" /etc/wireguard/wgcf.conf;
        sed -i "s#PrivateKey.*#PrivateKey = $warpPrivateKey#g" /etc/wireguard/wgcf.conf;
        sed -i "s#Address.*32#Address = $warpIPv4Address#g" /etc/wireguard/wgcf.conf;
        sed -i "s#Address.*128#Address = $warpIPv6Address#g" /etc/wireguard/wgcf.conf;
        wg-quick up wgcf >/dev/null 2>&1
        yellow "正在检查Wgcf-WARP的WARP 免费账户连通性，请稍等..." && sleep 5
        checkwarp
        if [[ $wpv4 == "on" ]] || [[ $wpv6 == "on" ]]; then
            green "Wgcf-WARP 账户类型切换为 WARP 免费账户 成功！"
        else
            wg-quick down wgcf >/dev/null 2>&1
            red "切换 Wgcf-WARP 账户类型失败，请尝试卸载后重装以重新切换账户！"
            exit 1
        fi
    fi
    if [[ $accountInput == 2 ]]; then
        cd /etc/wireguard
        if [[ ! -f wgcf-account.toml ]]; then
            until [[ -a wgcf-account.toml ]]; do
                wgcf register --accept-tos
                sleep 5
            done
        fi
        chmod +x wgcf-account.toml
        yellow "获取CloudFlare WARP账号密钥信息方法: "
        green "电脑: 下载并安装CloudFlare WARP→设置→偏好设置→账户→复制密钥到脚本中"
        green "手机: 下载并安装1.1.1.1 APP→菜单→账户→复制密钥到脚本中"
        echo ""
        yellow "重要：请确保手机或电脑的1.1.1.1 APP的账户状态为WARP+！"
        read -rp "输入WARP账户许可证密钥 (26个字符): " warpkey
        until [[ -z $warpkey || $warpkey =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}$ ]]; do
            red "WARP账户许可证密钥格式输入错误，请重新输入！"
            read -rp "输入WARP账户许可证密钥 (26个字符): " warpkey
        done
        if [[ -n $warpkey ]]; then
            sed -i "s/license_key.*/license_key = \"$warpkey\"/g" wgcf-account.toml
            read -rp "请输入自定义设备名，如未输入则使用默认随机设备名: " devicename
            rm -f wgcf-profile.conf
            green "注册WARP+账户中, 如下方显示:400 Bad Request, 则使用WARP免费版账户"
            if [[ -n $devicename ]]; then
                wgcf update --name $(echo $devicename | sed s/[[:space:]]/_/g) > /etc/wireguard/info.log 2>&1
            else
                wgcf update > /etc/wireguard/info.log 2>&1
            fi
            wgcf generate
            chmod +x wgcf-profile.conf
            wg-quick down wgcf >/dev/null 2>&1
            warpPublicKey=$(grep PublicKey /etc/wireguard/wgcf-profile.conf | sed "s/PublicKey = //g")
            warpPrivateKey=$(grep PrivateKey /etc/wireguard/wgcf-profile.conf | sed "s/PrivateKey = //g")
            warpIPv4Address=$(cat /etc/wireguard/wgcf-profile.conf | sed -n 3p | sed "s/Address = //g")
            warpIPv6Address=$(cat /etc/wireguard/wgcf-profile.conf | sed -n 4p | sed "s/Address = //g")
            sed -i "s#PublicKey.*#PublicKey = $warpPublicKey#g" /etc/wireguard/wgcf.conf;
            sed -i "s#PrivateKey.*#PrivateKey = $warpPrivateKey#g" /etc/wireguard/wgcf.conf;
            sed -i "s#Address.*32#Address = $warpIPv4Address#g" /etc/wireguard/wgcf.conf;
            sed -i "s#Address.*128#Address = $warpIPv6Address#g" /etc/wireguard/wgcf.conf;
            wg-quick up wgcf >/dev/null 2>&1
            yellow "正在检查Wgcf-WARP的WARP+账户连通性，请稍等..." && sleep 5
            checkwarp
            if [[ $gbwpv4 == "plus" ]] || [[ $gbwpv6 == "plus" ]]; then
                green "Wgcf-WARP 账户类型切换为 WARP+ 成功！"
            else
                wg-quick down wgcf >/dev/null 2>&1
                cd /etc/wireguard
                rm -f wgcf-account.toml wgcf-profile.conf
                until [[ -a wgcf-account.toml ]]; do
                    wgcf register --accept-tos
                    sleep 5
                done
                wgcf generate
                chmod +x wgcf-profile.conf
                warpPublicKey=$(grep PublicKey /etc/wireguard/wgcf-profile.conf | sed "s/PublicKey = //g")
                warpPrivateKey=$(grep PrivateKey /etc/wireguard/wgcf-profile.conf | sed "s/PrivateKey = //g")
                warpIPv4Address=$(cat /etc/wireguard/wgcf-profile.conf | sed -n 3p | sed "s/Address = //g")
                warpIPv6Address=$(cat /etc/wireguard/wgcf-profile.conf | sed -n 4p | sed "s/Address = //g")
                sed -i "s#PublicKey.*#PublicKey = $warpPublicKey#g" /etc/wireguard/wgcf.conf;
                sed -i "s#PrivateKey.*#PrivateKey = $warpPrivateKey#g" /etc/wireguard/wgcf.conf;
                sed -i "s#Address.*32#Address = $warpIPv4Address#g" /etc/wireguard/wgcf.conf;
                sed -i "s#Address.*128#Address = $warpIPv6Address#g" /etc/wireguard/wgcf.conf;
                wg-quick up wgcf >/dev/null 2>&1
                red "切换 Wgcf-WARP 账户类型失败，已自动切换为WARP 免费账户！"
                green "建议如下："
                yellow "1. 检查1.1.1.1 APP中的WARP+账户是否有足够的流量，如没有流量可以使用本脚本内的刷流量功能来获取免费的WARP+流量"
                yellow "2. 检查当前WARP许可证密钥是否绑定超过5台设备"
                yellow "3. 脚本可能跟不上时代, 建议截图发布到GitHub Issues或TG群询问"
                exit 1
            fi
        fi
    fi
    if [[ $accountInput == 3 ]]; then
        read -rp "请复制粘贴WARP Teams账户配置文件链接 [如未输入则使用脚本默认的]：" teamconfigurl
        if [[ -z $teamconfigurl ]]; then
            yellow "未输入Teams账户配置文件链接，正在使用脚本公用Teams账户..."
            teamconfigurl="https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/teams.xml"
        fi
        teamsconfig=$(curl -sSL "$teamconfigurl" | sed "s/\"/\&quot;/g")
        wpteampublickey=$(expr "$teamsconfig" : '.*public_key&quot;:&quot;\([^&]*\).*')
        wpteamprivatekey=$(expr "$teamsconfig" : '.*private_key&quot;>\([^<]*\).*')
        wpteamv6address=$(expr "$teamsconfig" : '.*v6&quot;:&quot;\([^[&]*\).*')
        wpteamv4address=$(expr "$teamsconfig" : '.*v4&quot;:&quot;\(172[^&]*\).*')
        green "你的WARP Teams配置文件信息如下:"
        yellow "PublicKey: $wpteampublickey"
        yellow "PrivateKey: $wpteamprivatekey"
        yellow "IPv4地址: $wpteamv4address"
        yellow "IPv6地址: $wpteamv6address"
        read -rp "确认以上配置信息信息正确请输入y, 其他按键退出升级过程: " wpteamconfirm
        if [[ $wpteamconfirm =~ "y"|"Y" ]]; then
            if [[ -n $(type -P wgcf) && -n $(type -P wg-quick) ]]; then
                wg-quick down wgcf >/dev/null 2>&1
                sed -i "s#PublicKey.*#PublicKey = $wpteampublickey#g" /etc/wireguard/wgcf.conf;
                sed -i "s#PrivateKey.*#PrivateKey = $wpteamprivatekey#g" /etc/wireguard/wgcf.conf;
                sed -i "s#Address.*32#Address = $wpteamv4address/32#g" /etc/wireguard/wgcf.conf;
                sed -i "s#Address.*128#Address = $wpteamv6address/128#g" /etc/wireguard/wgcf.conf;
                sed -i "s#PublicKey.*#PublicKey = $wpteampublickey#g" /etc/wireguard/wgcf-profile.conf;
                sed -i "s#PrivateKey.*#PrivateKey = $wpteamprivatekey#g" /etc/wireguard/wgcf-profile.conf;
                sed -i "s#Address.*32#Address = $wpteamv4address/32#g" /etc/wireguard/wgcf-profile.conf;
                sed -i "s#Address.*128#Address = $wpteamv6address/128#g" /etc/wireguard/wgcf-profile.conf;
                wg-quick up wgcf >/dev/null 2>&1
                yellow "正在检查Wgcf-WARP的WARP Teams账户连通性, 请稍等..."
                checkwarp
                retry_time=1
                until [[ $wpv4 =~ on|plus ]] || [[ $wpv6 =~ on|plus ]]; do
                    red "无法联通WARP Teams账户, 正在尝试重启, 重试次数：$retry_time"
                    retry_time=$((${retry_time} + 1))
                    if [[ $retry_time == 4 ]]; then
                        wg-quick down wgcf >/dev/null 2>&1
                        cd /etc/wireguard
                        rm -f wgcf-profile.conf
                        wgcf generate
                        chmod +x wgcf-profile.conf
                        warpPublicKey=$(grep PublicKey /etc/wireguard/wgcf-profile.conf | sed "s/PublicKey = //g")
                        warpPrivateKey=$(grep PrivateKey /etc/wireguard/wgcf-profile.conf | sed "s/PrivateKey = //g")
                        warpIPv4Address=$(cat /etc/wireguard/wgcf-profile.conf | sed -n 3p | sed "s/Address = //g")
                        warpIPv6Address=$(cat /etc/wireguard/wgcf-profile.conf | sed -n 4p | sed "s/Address = //g")
                        sed -i "s#PublicKey.*#PublicKey = $warpPublicKey#g" /etc/wireguard/wgcf.conf;
                        sed -i "s#PrivateKey.*#PrivateKey = $warpPrivateKey#g" /etc/wireguard/wgcf.conf;
                        sed -i "s#Address.*32#Address = $warpIPv4Address#g" /etc/wireguard/wgcf.conf;
                        sed -i "s#Address.*128#Address = $warpIPv6Address#g" /etc/wireguard/wgcf.conf;
                        wg-quick up wgcf >/dev/null 2>&1
                        red "WARP Teams配置可能有误, 已自动降级至WARP 免费账户 / WARP+"
                        green "建议如下："
                        yellow "1. 检查提取出来的配置文件是否为从安卓5.1模拟器，1.1.1.1 APP 6.9版本的"
                        yellow "2. 你有可能修改了团队名、删除了设备"
                        yellow "3. 脚本可能跟不上时代, 建议截图发布到GitLab Issues或TG群询问"
                        exit 1
                    fi
                done
                green "Wgcf-WARP 账户类型切换为 WARP Teams 成功！"
            fi
        fi
    fi
}

wpgoaccount(){
    checkwarp
    if [[ $wpv4 =~ on|plus ]] || [[ $wpv6 =~ on|plus ]]; then
        systemctl stop warp-go
        checkstack
        systemctl start warp-go
    else
        checkstack
    fi

    currallowips=$(cat /opt/warp-go/warp.conf | grep AllowedIPs)

    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        currendpoint=$wgo4
        currpost=$wgo6
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        currendpoint=$wgo5
        currpost=$wgo7
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        currendpoint=$wgo4
        currpost=$wgo8
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        currendpoint=$wgo5
        currpost=$wgo8
    fi

    yellow "请选择将要切换的WARP账户类型："
    green "1. WARP 免费版账户 （默认）"
    green "2. WARP+"
    green "3. WARP Teams"
    read -rp "请输入选项 [1-3]：" accountInput
    if [[ $accountInput == 1 ]]; then
        systemctl stop warp-go
        until [[ -e /opt/warp-go/warp.conf ]]; do
            yellow "正在向CloudFlare WARP注册账号, 如出现Success即为注册成功"
            /opt/warp-go/warp-go --register --config=/opt/warp-go/warp.conf
        done
        sed -i "s#.*AllowedIPs.*#$currallowips#g" /opt/warp-go/warp.conf
        echo $currendpoint | sh
        echo $currpost | sh
        systemctl start warp-go && sleep 3
        checkwarp
        if [[ $wpv4 == "on" ]] || [[ $wpv6 == "on" ]]; then
            green "WARP 免费账户切换成功！"
        elif [[ $wpv4 == "plus" ]] || [[ $wpv6 == "plus" ]]; then
            yellow "可能是WARP-Go出现Bug了，目前已经是WARP Teams账户"
        else
            red "WARP 免费账户切换失败！"
        fi
    fi
    if [[ $accountInput == 2 ]]; then
        yellow "获取CloudFlare WARP账号密钥信息方法: "
        green "电脑: 下载并安装CloudFlare WARP→设置→偏好设置→账户→复制密钥到脚本中"
        green "手机: 下载并安装1.1.1.1 APP→菜单→账户→复制密钥到脚本中"
        echo ""
        yellow "重要：请确保手机或电脑的1.1.1.1 APP的账户状态为WARP+！"
        read -rp "输入WARP账户许可证密钥 (26个字符): " warpkey
        until [[ -z $warpkey || $warpkey =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}$ ]]; do
            red "WARP账户许可证密钥格式输入错误，请重新输入！"
            read -rp "输入WARP账户许可证密钥 (26个字符): " warpkey
        done
        read -rp "请输入自定义设备名，如未输入则使用默认随机设备名: " devicename
        systemctl stop warp-go
        yellow "正在向CloudFlare WARP注册账号, 如出现Success即为注册成功"
        result=$(/opt/warp-go/warp-go --register --config=/opt/warp-go/warp.conf --license=$warpkey --device-name=$devicename)
        if [[ $result == "Success" ]]; then
            sed -i "s#.*AllowedIPs.*#$currallowips#g" /opt/warp-go/warp.conf
            echo $currendpoint | sh
            echo $currpost | sh
            systemctl start warp-go && sleep 3
            checkwarp
            if [[ $wpv4 == "plus" ]] || [[ $wpv6 == "plus" ]]; then
                green "WARP+ 账户升级成功！"
            else
                red "WARP+ 账户升级失败！"
            fi
        else
            red "WARP+ 账户注册失败！正在还原为WARP 免费账户"
            systemctl stop warp-go
            until [[ -e /opt/warp-go/warp.conf ]]; do
                yellow "正在向CloudFlare WARP注册账号, 如出现Success即为注册成功"
                /opt/warp-go/warp-go --register --config=/opt/warp-go/warp.conf
            done
            sed -i "s#.*AllowedIPs.*#$currallowips#g" /opt/warp-go/warp.conf
            echo $currendpoint | sh
            echo $currpost | sh
            systemctl start warp-go && sleep 3
            red "WARP+账户升级失败！"
            green "建议如下："
            yellow "1. 检查1.1.1.1 APP中的WARP+账户是否有足够的流量，如没有流量可以使用本脚本内的刷流量功能来获取免费的WARP+流量"
            yellow "2. 检查当前WARP许可证密钥是否绑定超过5台设备"
            yellow "3. 脚本可能跟不上时代, 建议截图发布到GitHub Issues或TG群询问"
        fi
    fi
    if [[ $accountInput == 3 ]]; then
        read -rp "请输入Teams账户TOKEN: " teamstoken
        systemctl stop warp-go
        if [[ -n $teamstoken ]]; then
            yellow "正在向CloudFlare WARP注册账号, 如出现Success即为注册成功"
            rm -f /opt/warp-go/warp.conf
            result=$(/opt/warp-go/warp-go --register --config=/opt/warp-go/warp.conf --team-config "$teamstoken")
            sed -i "s#.*AllowedIPs.*#$currallowips#g" /opt/warp-go/warp.conf
            echo $currendpoint | sh
            echo $currpost | sh
            systemctl start warp-go && sleep 3
            checkgbwp
            if [[ $gbwpv4 == "plus" ]] || [[ $gbwpv6 == "plus" ]]; then
                green "WARP Teams账户升级成功！"
            else
                red "WARP Teams账户注册失败！正在还原为WARP 免费账户"
                until [[ -e /opt/warp-go/warp.conf ]]; do
                    yellow "正在向CloudFlare WARP注册账号, 如出现Success即为注册成功"
                    /opt/warp-go/warp-go --register --config=/opt/warp-go/warp.conf
                done
                sed -i "s#.*AllowedIPs.*#$currallowips#g" /opt/warp-go/warp.conf
                echo $currendpoint | sh
                echo $currpost | sh
                systemctl start warp-go && sleep 3
                red "WARP Teams账户升级失败！"
                green "建议如下："
                yellow "1. 检查提取出来的TOKEN是否过期或不可用"
                yellow "2. 你有可能修改了团队名、删除了设备"
                yellow "3. 脚本可能跟不上时代, 建议截图发布到GitHub Issues或TG群询问"
            fi
        else
            red "未输入Teams TOKEN，取消升级账户！"
            exit 1
        fi
    fi
}

warpaccount(){
    yellow "请选择将要切换账户的WARP客户端："
    green "1. Wgcf-WARP （默认）"
    green "2. WARP-Go"
    read -rp "请输入选项 [1-2]：" clientInput
    case $clientInput in
        2 ) wpgoaccount ;;
        * ) wgcfaccount ;;
    esac
}

ipinfo(){
    d4="${RED}未设置${PLAIN}"
    d6="${RED}未设置${PLAIN}"
    c4=$(curl -sm8 ipget.net/country?ip=$ipv4)
    c6=$(curl -sm8 ipget.net/country?ip=$ipv6)
    n4=$(nf | sed -n 3p | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")
    n6=$(nf | sed -n 7p | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")

    if [[ -n $(echo $n6 | grep "NF所识别的IP地域信息") ]]; then
        n6=$(nf | sed -n 6p | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")
    fi

    if [[ $wpv4 == "plus" ]]; then
        if [[ -n $(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }') ]]; then
            d4=$(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }')
            check_quota
            t4="${GREEN} $QUOTA ${PLAIN}"
            w4="${GREEN}WARP+${PLAIN}"
        elif [[ $(grep -s "Type" /opt/warp-go/warp.conf | cut -d= -f2 | sed "s# ##g") == "plus" ]]; then
            check_quota
            t4="${GREEN} $QUOTA ${PLAIN}"
            w4="${GREEN}WARP+${PLAIN}"
        else
            t4="${RED}无限制${PLAIN}"
            w4="${GREEN}WARP Teams${PLAIN}"
        fi
    elif [[ $wpv4 == "on" ]]; then
        t4="${RED}无限制${PLAIN}"
        w4="${YELLOW}WARP 免费账户${PLAIN}"
    else
        t4="${RED}无限制${PLAIN}"
        w4="${RED}未启用WARP${PLAIN}"
    fi
    if [[ $wpv6 == "plus" ]]; then
        if [[ -n $(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }') ]]; then
            d6=$(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }')
            check_quota
            t6="${GREEN} $QUOTA ${PLAIN}"
            w6="${GREEN}WARP+${PLAIN}"
        elif [[ $(grep -s "Type" /opt/warp-go/warp.conf | cut -d= -f2 | sed "s# ##g") == "plus" ]]; then
            check_quota
            t4="${GREEN} $QUOTA ${PLAIN}"
            w4="${GREEN}WARP+${PLAIN}"
        else
            t6="${RED}无限制${PLAIN}"
            w6="${GREEN}WARP Teams${PLAIN}"
        fi
    elif [[ $wpv6 == "on" ]]; then
        t6="${RED}无限制${PLAIN}"
        w6="${YELLOW}WARP 免费账户${PLAIN}"
    else
        t6="${RED}无限制${PLAIN}"
        w6="${RED}未启用WARP${PLAIN}"
    fi

    [[ $n4 == "您的出口IP完整解锁Netflix，支持非自制剧的观看" ]] && n4="${GREEN}已解锁 Netflix${PLAIN}"
    [[ $n6 == "您的出口IP完整解锁Netflix，支持非自制剧的观看" ]] && n6="${GREEN}已解锁 Netflix${PLAIN}"
    [[ $n4 == "您的出口IP可以使用Netflix，但仅可看Netflix自制剧" ]] && n4="${YELLOW}Netflix 自制剧${PLAIN}"
    [[ $n6 == "您的出口IP可以使用Netflix，但仅可看Netflix自制剧" ]] && n6="${YELLOW}Netflix 自制剧${PLAIN}"
    [[ -z $n4 ]] || [[ $n4 == "您的网络可能没有正常配置IPv4，或者没有IPv4网络接入" ]] && n4="${RED}无法检测Netflix状态${PLAIN}"
    [[ -z $n6 ]] || [[ $n6 == "您的网络可能没有正常配置IPv6，或者没有IPv6网络接入" ]] && n6="${RED}无法检测Netflix状态${PLAIN}"
    [[ $n4 =~ "Netflix在您的出口IP所在的国家不提供服务"|"Netflix在您的出口IP所在的国家提供服务，但是您的IP疑似代理，无法正常使用服务" ]] && n4="${RED}无法解锁 Netflix${PLAIN}"
    [[ $n6 =~ "Netflix在您的出口IP所在的国家不提供服务"|"Netflix在您的出口IP所在的国家提供服务，但是您的IP疑似代理，无法正常使用服务" ]] && n6="${RED}无法解锁 Netflix${PLAIN}"


    if [[ -n $ipv4 ]]; then
        echo "----------------------------------------------------------------------------"
        echo -e "IPv4 地址：$ipv4  地区：$c4  设备名称：$d4"
        echo -e "WARP状态：$w4  剩余流量：$t4  Netfilx解锁状态：$n4"
    fi
    if [[ -n $ipv6 ]]; then
        echo "----------------------------------------------------------------------------"
        echo -e "IPv6 地址：$ipv6  地区：$c6  设备名称：$d6"
        echo -e "WARP状态：$w6  剩余流量：$t6  Netfilx解锁状态：$n6"
    fi
    echo "----------------------------------------------------------------------------"
}

menu(){
    clear
    echo "#############################################################"
    echo -e "#                ${RED}CloudFlare WARP 一键管理脚本${PLAIN}               #"
    echo -e "# ${GREEN}作者${PLAIN}: MisakaNo の 小破站                                  #"
    echo -e "# ${GREEN}博客${PLAIN}: https://blog.misaka.rest                            #"
    echo -e "# ${GREEN}GitHub 项目${PLAIN}: https://github.com/Misaka-blog               #"
    echo -e "# ${GREEN}Telegram 频道${PLAIN}: https://t.me/misaka_noc                    #"
    echo -e "# ${GREEN}Telegram 群组${PLAIN}: https://t.me/misaka_noc_chat               #"
    echo -e "# ${GREEN}YouTube 频道${PLAIN}: https://www.youtube.com/@misaka-blog        #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 / 切换 Wgcf-WARP"
    echo -e " ${GREEN}2.${PLAIN} ${RED}卸载 Wgcf-WARP${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}3.${PLAIN} 安装 / 切换 WARP-GO"
    echo -e " ${GREEN}4.${PLAIN} ${RED}卸载 WARP-GO${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}5.${PLAIN} 开启、关闭或重启 WARP"
    echo -e " ${GREEN}6.${PLAIN} 提取 WireGuard 配置文件"
    echo -e " ${GREEN}7.${PLAIN} WARP+ 账户刷流量"
    echo -e " ${GREEN}8.${PLAIN} 切换 WARP 账户类型"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    ipinfo
    echo ""
    read -rp "请输入选项 [0-8]: " menuInput
    case $menuInput in
        1 ) infowgcf ;;
        2 ) unstwgcf ;;
        3 ) infowpgo ;;
        4 ) unstwpgo ;;
        5 ) warpswitch ;;
        6 ) wgprofile ;;
        7 ) warptraffic ;;
        8 ) warpaccount ;;
        * ) exit 1 ;;
    esac
}

yellow "正在检测VPS网络环境，请稍后..."
checkv4v6
checkwarp
menu