#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora" "alpine")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora" "Alpine")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update" "apk update -f")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install" "apk add -f")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove" "apk del -f")

[[ $EUID -ne 0 ]] && red "注意：请在root用户下运行脚本" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
    fi
done

[[ -z $SYSTEM ]] && red "不支持当前VPS系统, 请使用主流的操作系统" && exit 1

# 某些系统未自带 curl，检测并安装
if [[ -z $(type -P curl) ]]; then
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} curl
fi

# 检查系统内核版本
main=$(uname -r | awk -F . '{print $1}')
minor=$(uname -r | awk -F . '{print $2}')
# 获取系统版本号
OSID=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
# 检查VPS虚拟化
VIRT=$(systemd-detect-virt)

# 删除 WGCF 默认配置文件中的监听 IP
wg1="sed -i '/0\.0\.0\.0\/0/d' /etc/wireguard/wgcf.conf" # IPv4
wg2="sed -i '/\:\:\/0/d' /etc/wireguard/wgcf.conf"       # IPv6

# 设置 WGCF 配置文件的 DNS 服务器
wg3="sed -i 's/1.1.1.1/1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4,2606:4700:4700::1111,2606:4700:4700::1001,2001:4860:4860::8888,2001:4860:4860::8844/g' /etc/wireguard/wgcf.conf"
wg4="sed -i 's/1.1.1.1/2606:4700:4700::1111,2606:4700:4700::1001,2001:4860:4860::8888,2001:4860:4860::8844,1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4/g' /etc/wireguard/wgcf.conf"

# 设置允许外部 IP 访问
wg5='sed -i "s/^/PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "s/^/PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf'                           # IPv4
wg6='sed -i "s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf' # IPv6
wg7='sed -i "s/^/PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "s/^/PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf' # 双栈

# 设置 WARP-GO 配置文件的监听 IP
wgo1='sed -i '\''s#.*AllowedIPs.*#AllowedIPs = 0.0.0.0/0#g;0,/AllowedIPs/s//# &/'\'' /opt/warp-go/warp.conf'      # IPv4
wgo2='sed -i '\''s#.*AllowedIPs.*#AllowedIPs = ::/0#g;0,/AllowedIPs/s//# &/'\'' /opt/warp-go/warp.conf'           # IPv6
wgo3='sed -i '\''s#.*AllowedIPs.*#AllowedIPs = 0.0.0.0/0,::/0#g;0,/AllowedIPs/s//# &/'\'' /opt/warp-go/warp.conf' # 双栈

# 设置允许外部 IP 访问
wgo4='sed -i "/\[Script\]/a PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf && sed -i "/\[Script\]/a PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf'                            # IPv4
wgo5='sed -i "/\[Script\]/a PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf && sed -i "/\[Script\]/a PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf'  # IPv6
wgo6='sed -i "/\[Script\]/a PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf && sed -i "/\[Script\]/a PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf && sed -i "/\[Script\]/a PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf && sed -i "/\[Script\]/a PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf' # 双栈

# 检测 VPS 处理器架构
archAffix() {
    case "$(uname -m)" in
        i386 | i686 ) echo '386' ;;
        x86_64 | amd64 ) echo 'amd64' ;;
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        s390x ) echo 's390x' ;;
        *) red "不支持的CPU架构!" && exit 1 ;;
    esac
}

# 检测 VPS 的出站 IP
check_ip() {
    ipv4=$(expr "$(curl -ks4m8 -A Mozilla https://api.ip.sb/geoip)" : '.*ip\":[ ]*\"\([^"]*\).*')
    ipv6=$(expr "$(curl -ks6m8 -A Mozilla https://api.ip.sb/geoip)" : '.*ip\":[ ]*\"\([^"]*\).*')
}

# 检测 VPS 的 IP 形式
check_stack() {
    lan4=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
    lan6=$(ip route get 2606:4700:4700::1111 2>/dev/null | grep -oP 'src \K\S+')
    if [[ "$lan4" =~ ^([0-9]{1,3}\.){3} ]]; then
        ping -c2 -W3 1.1.1.1 >/dev/null 2>&1 && out4=1
    fi
    if [[ "$lan6" != "::1" && "$lan6" =~ ^([a-f0-9]{1,4}:){2,4}[a-f0-9]{1,4} ]]; then
        ping6 -c2 -w10 2606:4700:4700::1111 >/dev/null 2>&1 && out6=1
    fi
}

# 检测 VPS 的 WARP 状态
check_warp() {
    warp_v4=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    warp_v6=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
}

# 检测 WARP+ 账户流量情况
check_quota() {
    if [[ "$CHECK_TYPE" = 1 ]]; then
        # 如为WARP-Cli，使用其自带接口获取流量
        QUOTA=$(warp-cli --accept-tos account 2>/dev/null | grep -oP 'Quota: \K\d+')
    else
        # 判断为 WGCF 或 WARP-GO，从客户端相应的配置文件中提取
        if [[ -e "/opt/warp-go/warp-go" ]]; then
            ACCESS_TOKEN=$(grep 'Token' /opt/warp-go/warp.conf | cut -d= -f2 | sed 's# ##g')
            DEVICE_ID=$(grep 'Device' /opt/warp-go/warp.conf | cut -d= -f2 | sed 's# ##g')
        fi
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            ACCESS_TOKEN=$(grep 'access_token' /etc/wireguard/wgcf-account.toml | cut -d \' -f2)
            DEVICE_ID=$(grep 'device_id' /etc/wireguard/wgcf-account.toml | cut -d \' -f2)
        fi

        # 使用API，获取流量信息
        API=$(curl -s "https://api.cloudflareclient.com/v0a884/reg/$DEVICE_ID" -H "User-Agent: okhttp/3.12.1" -H "Authorization: Bearer $ACCESS_TOKEN")
        QUOTA=$(grep -oP '"quota":\K\d+' <<<$API)
    fi

    # 流量单位换算
    [[ $QUOTA -gt 10000000000000 ]] && QUOTA="$(echo "scale=2; $QUOTA/1000000000000" | bc) TB" || QUOTA="$(echo "scale=2; $QUOTA/1000000000" | bc) GB"
}

# 检查 TUN 模块是否开启
check_tun() {
    TUN=$(cat /dev/net/tun 2>&1 | tr '[:upper:]' '[:lower:]')
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

# 修改 IPv4 / IPv6 优先级设置
stack_priority(){
    [[ -e /etc/gai.conf ]] && sed -i '/^precedence \:\:ffff\:0\:0/d;/^label 2002\:\:\/16/d' /etc/gai.conf
    
    yellow "选择 IPv4 / IPv6 优先级"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} IPv4 优先"
    echo -e " ${GREEN}2.${PLAIN} IPv6 优先"
    echo -e " ${GREEN}3.${PLAIN} 默认优先级 ${YELLOW}(默认)${PLAIN}"
    echo ""
    read -rp "请选择选项 [1-3]：" priority
    case $priority in
        1 ) echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf ;;
        2 ) echo "label 2002::/16   2" >> /etc/gai.conf ;;
        * ) yellow "将使用 VPS 默认的 IP 优先级" ;;
    esac
}

# 检查适合 VPS 的最佳 MTU 值
check_mtu() {
    yellow "正在检测并设置 MTU 最佳值, 请稍等..."
    check_ip
    MTUy=1500
    MTUc=10
    if [[ -n ${ipv6} && -z ${ipv4} ]]; then
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
    # 将 MTU 最佳值放置至 MTU 变量中备用
    MTU=$((${MTUy} - 80))

    green "MTU 最佳值 = $MTU 已设置完毕！"
}

# 检查适合 VPS 的最佳 Endpoint IP 地址
check_endpoint() {
    yellow "正在检测并设置最佳 Endpoint IP，请稍等，大约需要 1-2 分钟..."

    # 下载优选工具软件，感谢某匿名网友的分享的优选工具
    wget https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-yxip/warp-linux-$(archAffix) -O warp >/dev/null 2>&1

    # 根据 VPS 的出站 IP 情况，生成对应的优选 Endpoint IP 段列表
    check_ip

    if [[ -n $ipv4 ]]; then
        n=0
        iplist=100
        while true; do
            temp[$n]=$(echo 162.159.192.$(($RANDOM % 256)))
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo 162.159.193.$(($RANDOM % 256)))
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo 162.159.195.$(($RANDOM % 256)))
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo 188.114.96.$(($RANDOM % 256)))
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo 188.114.97.$(($RANDOM % 256)))
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo 188.114.98.$(($RANDOM % 256)))
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo 188.114.99.$(($RANDOM % 256)))
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
        done
        while true; do
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 162.159.192.$(($RANDOM % 256)))
                n=$(($n + 1))
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 162.159.193.$(($RANDOM % 256)))
                n=$(($n + 1))
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 162.159.195.$(($RANDOM % 256)))
                n=$(($n + 1))
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 188.114.96.$(($RANDOM % 256)))
                n=$(($n + 1))
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 188.114.97.$(($RANDOM % 256)))
                n=$(($n + 1))
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 188.114.98.$(($RANDOM % 256)))
                n=$(($n + 1))
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 188.114.99.$(($RANDOM % 256)))
                n=$(($n + 1))
            fi
        done
    else
        n=0
        iplist=100
        while true; do
            temp[$n]=$(echo [2606:4700:d0::$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2)))])
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo [2606:4700:d1::$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2)))])
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
        done
        while true; do
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo [2606:4700:d0::$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2)))])
                n=$(($n + 1))
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo [2606:4700:d1::$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2)))])
                n=$(($n + 1))
            fi
        done
    fi

    # 将生成的 IP 段列表放到 ip.txt 里，待程序优选
    echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u > ip.txt

    # 取消 Linux 自带的线程限制，以便生成优选 Endpoint IP
    ulimit -n 102400

    # 启动 WARP Endpoint IP 优选工具
    chmod +x warp && ./warp >/dev/null 2>&1

    # 将 result.csv 文件的优选 Endpoint IP 提取出来，放置到 best_endpoint 变量中备用
    best_endpoint=$(cat result.csv | sed -n 2p | awk -F ',' '{print $1}')

    # 查询优选出来的 Endpoint IP 的 loss 是否为 100.00%，如是，则替换为默认的 Endpoint IP
    endpoint_loss=$(cat result.csv | sed -n 2p | awk -F ',' '{print $2}')
    if [[ $endpoint_loss == "100.00%" ]]; then
        # 检查 VPS 的出站 IP 情况
        check_ip

        # 如未有 IPv4 则使用 IPv6 的 Endpoint IP，如有 IPv4 则使用 IPv4 Endpoint IP
        if [[ -z $ipv4 ]]; then
            best_endpoint="[2606:4700:d0::a29f:c001]:2408"
        else
            best_endpoint="162.159.193.10:2408"
        fi
    fi

    # 删除 WARP Endpoint IP 优选工具及其附属文件
    rm -f warp ip.txt result.csv

    green "最佳 Endpoint IP = $best_endpoint 已设置完毕！"
}

# 选择 WGCF 安装 / 切换模式
select_wgcf() {
    yellow "请选择 WGCF 安装 / 切换的模式"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 / 切换 WGCF-WARP 单栈模式 ${YELLOW}(IPv4)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 安装 / 切换 WGCF-WARP 单栈模式 ${YELLOW}(IPv6)${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} 安装 / 切换 WGCF-WARP 双栈模式"
    echo ""
    read -p "请输入选项 [1-3]: " wgcf_mode
    if [ "$wgcf_mode" = "1" ]; then
        install_wgcf_ipv4
    elif [ "$wgcf_mode" = "2" ]; then
        install_wgcf_ipv6
    elif [ "$wgcf_mode" = "3" ]; then
        install_wgcf_dual
    else
        red "输入错误，请重新输入"
        select_wgcf
    fi
}

install_wgcf_ipv4() {
    # 检查 WARP 状态
    check_warp

    # 如启动 WARP，则关闭
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # 因为 WGCF 和 WARP-GO 冲突，故检测 WARP-GO 之后打断安装
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        red "WARP-GO 已安装，请先卸载 WARP-GO"
        exit 1
    fi

    # 检查 VPS 的 IP 形式
    check_stack

    # 根据检测结果，选择适合的模式安装
    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        # IPv4 Only
        wgcf1=$wg2 && wgcf2=$wg3 && wgcf3=$wg5
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # IPv6 Only
        wgcf1=$wg2 && wgcf2=$wg4
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        # 双栈
        wgcf1=$wg2 && wgcf2=$wg3 && wgcf3=$wg5
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # NAT IPv4 + IPv6
        wgcf1=$wg2 && wgcf2=$wg4 && wgcf3=$wg5
    fi

    # 检测是否安装 WGCF，如安装，则切换配置文件。反之执行安装操作
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        switch_wgcf_conf
    else
        install_wgcf
    fi
}

install_wgcf_ipv6() {
    # 检查 WARP 状态
    check_warp

    # 如启动 WARP，则关闭
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # 因为 WGCF 和 WARP-GO 冲突，故检测 WARP-GO 之后打断安装
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        red "WARP-GO 已安装，请先卸载 WARP-GO"
        exit 1
    fi

    # 检查 VPS 的 IP 形式
    check_stack

    # 根据检测结果，选择适合的模式安装
    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        # IPv4 Only
        wgcf1=$wg1 && wgcf2=$wg3
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # IPv6 Only
        wgcf1=$wg1 && wgcf2=$wg4 && wgcf3=$wg6
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        # 双栈
        wgcf1=$wg1 && wgcf2=$wg3 && wgcf3=$wg6
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # NAT IPv4 + IPv6
        wgcf1=$wg1 && wgcf2=$wg4 && wgcf3=$wg6
    fi

    # 检测是否安装 WGCF，如安装，则切换配置文件。反之执行安装操作
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        switch_wgcf_conf
    else
        install_wgcf
    fi
}

install_wgcf_dual() {
    # 检查 WARP 状态
    check_warp

    # 如启动 WARP，则关闭
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # 因为 WGCF 和 WARP-GO 冲突，故检测 WARP-GO 之后打断安装
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        red "WARP-GO 已安装，请先卸载 WARP-GO"
        exit 1
    fi

    # 检查 VPS 的 IP 形式
    check_stack

    # 根据检测结果，选择适合的模式安装
    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        # IPv4 Only
        wgcf1=$wg3 && wgcf2=$wg5
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # IPv6 Only
        wgcf1=$wg4 && wgcf2=$wg6
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        # 双栈
        wgcf1=$wg3 && wgcf2=$wg7
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # NAT IPv4 + IPv6
        wgcf1=$wg4 && wgcf2=$wg6
    fi

    # 检测是否安装 WGCF，如安装，则切换配置文件。反之执行安装操作
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        switch_wgcf_conf
    else
        install_wgcf
    fi
}

# 下载 WGCF
init_wgcf() {
    wget --no-check-certificate https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/wgcf/wgcf-latest-linux-$(archAffix) -O /usr/local/bin/wgcf
    chmod +x /usr/local/bin/wgcf
}

# 利用 WGCF 注册 CloudFlare WARP 账户
register_wgcf() {
    if [[ $country4 == "Russia" || $country6 == "Russia" ]]; then
        wget --no-check-certificate https://api.zeroteam.top/warp?format=wgcf -O wgcf.zip
        unzip wgcf.zip
        rm -f wgcf.zip
        chmod +x wgcf-account.toml wgcf-profile.conf
    else
        # 如已注册 WARP 账户，则自动拉取。避免造成 CloudFlare 服务器负担
        if [[ -f /etc/wireguard/wgcf-account.toml ]]; then
            cp -f /etc/wireguard/wgcf-account.toml /root/wgcf-account.toml
        fi

        # 注册 WARP 账户，直到注册成功为止
        until [[ -e wgcf-account.toml ]]; do
            yellow "正在向 CloudFlare WARP 注册账号, 如提示 429 Too Many Requests 错误请耐心等待脚本重试注册即可"
            wgcf register --accept-tos
            sleep 5
        done
        chmod +x wgcf-account.toml

        # 生成 WireGuard 配置文件
        wgcf generate && chmod +x wgcf-profile.conf
    fi
}

# 配置 WGCF 的 WireGuard 配置文件
conf_wgcf() {
    echo $wgcf1 | sh
    echo $wgcf2 | sh
    echo $wgcf3 | sh
}

# 检查 WGCF 是否启动成功，如未启动成功则提示
check_wgcf() {
    yellow "正在启动 WGCF-WARP"
    i=0
    while [ $i -le 4 ]; do
        let i++
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl start wg-quick@wgcf >/dev/null 2>&1
        check_warp
        if [[ $warp_v4 =~ on|plus ]] || [[ $warp_v6 =~ on|plus ]]; then
            green "WGCF-WARP 已启动成功！"
            systemctl enable wg-quick@wgcf >/dev/null 2>&1
            echo ""
            red "下面是恰饭广告："
            yellow "灵梦机场"
            green "专线节点加速、支持流媒体解锁、支持ChatGPT、晚高峰4k秒开、大多为x0.5倍节点，这一切，仅9.9元"
            yellow "优惠尽在：https://reimu.work/auth/register?code=aKKj"
            yellow "TG群：https://t.me/ReimuCloudGrup"
            echo ""
            before_showinfo && show_info
            break
        else
            red "WGCF-WARP 启动失败！"
        fi
        check_warp
        if [[ ! $warp_v4 =~ on|plus && ! $warp_v6 =~ on|plus ]]; then
            wg-quick down wgcf 2>/dev/null
            systemctl stop wg-quick@wgcf >/dev/null 2>&1
            systemctl disable wg-quick@wgcf >/dev/null 2>&1
            red "安装 WGCF-WARP 失败！"
            green "建议如下："
            yellow "1. 强烈建议使用官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为官方源"
            yellow "2. 部分 VPS 系统极度精简，相关依赖需自行安装后再尝试"
            yellow "3. 查看 https://www.cloudflarestatus.com/ ，你当前VPS就近区域可能处于黄色的【Re-routed】状态"
            yellow "4. WGCF 在香港、美西区域遭到 CloudFlare 官方封禁，请卸载 WGCF ，然后使用 WARP-GO 重试"
            yellow "5. 脚本可能跟不上时代, 建议截图发布到 GitLab Issues 或 TG 群询问"
            exit 1
        fi
    done
}

install_wgcf() {
    # 检测系统要求，如未达到要求则打断安装
    [[ $SYSTEM == "CentOS" ]] && [[ ${OSID} -lt 7 ]] && yellow "当前系统版本：${CMD} \nWGCF-WARP模式仅支持CentOS / Almalinux / Rocky / Oracle Linux 7及以上版本的系统" && exit 1
    [[ $SYSTEM == "Debian" ]] && [[ ${OSID} -lt 10 ]] && yellow "当前系统版本：${CMD} \nWGCF-WARP模式仅支持Debian 10及以上版本的系统" && exit 1
    [[ $SYSTEM == "Fedora" ]] && [[ ${OSID} -lt 29 ]] && yellow "当前系统版本：${CMD} \nWGCF-WARP模式仅支持Fedora 29及以上版本的系统" && exit 1
    [[ $SYSTEM == "Ubuntu" ]] && [[ ${OSID} -lt 18 ]] && yellow "当前系统版本：${CMD} \nWGCF-WARP模式仅支持Ubuntu 16.04及以上版本的系统" && exit 1

    # 检测 TUN 模块是否开启
    check_tun

    # 设置 IPv4 / IPv6 优先级
    stack_priority

    # 安装 WGCF 必需依赖
    if [[ $SYSTEM == "Alpine" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget bash grep net-tools iproute2 openresolv openrc iptables ip6tables wireguard-tools
    fi
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} epel-release
        ${PACKAGE_INSTALL[int]} sudo curl wget unzip iproute net-tools wireguard-tools iptables bc htop screen python3 iputils qrencode
        if [[ $OSID == 9 ]] && [[ -z $(type -P resolvconf) ]]; then
            wget -N https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/resolvconf -O /usr/sbin/resolvconf
            chmod +x /usr/sbin/resolvconf
        fi
    fi
    if [[ $SYSTEM == "Fedora" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget unzip iproute net-tools wireguard-tools iptables bc htop screen python3 iputils qrencode
    fi
    if [[ $SYSTEM == "Debian" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo wget curl unzip lsb-release bc htop screen python3 inetutils-ping qrencode
        echo "deb http://deb.debian.org/debian $(lsb_release -sc)-backports main" | tee /etc/apt/sources.list.d/backports.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi
    if [[ $SYSTEM == "Ubuntu" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget unzip lsb-release bc htop screen python3 inetutils-ping qrencode
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi

    # 如 Linux 系统内核版本 < 5.6，或为 OpenVZ / LXC 虚拟化架构的VPS，则安装 Wireguard-GO
    if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]] || [[ $VIRT =~ lxc|openvz ]]; then
        wget -N --no-check-certificate https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/wireguard-go/wireguard-go-$(archAffix) -O /usr/bin/wireguard-go
        chmod +x /usr/bin/wireguard-go
    fi

    # IPv4 only VPS 开启 IPv6 支持
    if [[ $(sysctl -a | grep 'disable_ipv6.*=.*1') || $(cat /etc/sysctl.{conf,d/*} | grep 'disable_ipv6.*=.*1') ]]; then
        sed -i '/disable_ipv6/d' /etc/sysctl.{conf,d/*}
        echo 'net.ipv6.conf.all.disable_ipv6 = 0' >/etc/sysctl.d/ipv6.conf
        sysctl -w net.ipv6.conf.all.disable_ipv6=0
    fi

    # 下载并安装 WGCF
    init_wgcf

    # 在 WGCF 处注册账户
    register_wgcf

    # 检测 /etc/wireguard 文件夹是否创建，如未创建则创建一个
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
    fi

    # 移动对应的配置文件，避免用户删除
    cp -f wgcf-profile.conf /etc/wireguard/wgcf.conf
    mv -f wgcf-profile.conf /etc/wireguard/wgcf-profile.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml

    # 设置 WGCF 的 WireGuard 配置文件
    conf_wgcf

    # 检查最佳 MTU 值，并应用至 WGCF 配置文件
    check_mtu
    sed -i "s/MTU.*/MTU = $MTU/g" /etc/wireguard/wgcf.conf

    # 优选 EndPoint IP，并应用至 WGCF 配置文件
    check_endpoint
    sed -i "s/engage.cloudflareclient.com:2408/$best_endpoint/g" /etc/wireguard/wgcf.conf

    # 启动 WGCF，并检查 WGCF 是否启动成功
    check_wgcf
}

switch_wgcf_conf() {
    # 关闭 WGCF
    wg-quick down wgcf 2>/dev/null
    systemctl stop wg-quick@wgcf 2>/dev/null
    systemctl disable wg-quick@wgcf 2>/dev/null

    # 删除配置好的 WGCF WireGuard 配置文件，并重新从 wgcf-profile.conf 拉取
    rm -rf /etc/wireguard/wgcf.conf
    cp -f /etc/wireguard/wgcf-profile.conf /etc/wireguard/wgcf.conf >/dev/null 2>&1

    # 设置 WGCF 的 WireGuard 配置文件
    conf_wgcf

    # 检查最佳 MTU 值，并应用至 WGCF 配置文件
    check_mtu
    sed -i "s/MTU.*/MTU = $MTU/g" /etc/wireguard/wgcf.conf

    # 优选 EndPoint IP，并应用至 WGCF 配置文件
    check_endpoint
    sed -i "s/engage.cloudflareclient.com:2408/$best_endpoint/g" /etc/wireguard/wgcf.conf

    # 启动 WGCF，并检查 WGCF 是否启动成功
    check_wgcf
}

# 卸载 WGCF
uninstall_wgcf() {
    # 关闭 WGCF
    wg-quick down wgcf 2>/dev/null
    systemctl stop wg-quick@wgcf 2>/dev/null
    systemctl disable wg-quick@wgcf 2>/dev/null

    # 卸载 WireGuard 依赖
    ${PACKAGE_UNINSTALL[int]} wireguard-tools

    # 因为 WireProxy 需要依赖 WGCF，如未检测到，则删除账户信息文件
    if [[ -z $(type -P wireproxy) ]]; then
        rm -f /usr/local/bin/wgcf
        rm -f /etc/wireguard/wgcf-profile.toml
        rm -f /etc/wireguard/wgcf-account.toml
    fi

    # 删除 WGCF WireGuard 配置文件
    rm -f /etc/wireguard/wgcf.conf

    # 如有 WireGuard-GO，则删除
    rm -f /usr/bin/wireguard-go

    # 恢复 VPS 默认的出站规则
    if [[ -e /etc/gai.conf ]]; then
        sed -i '/^precedence[ ]*::ffff:0:0\/96[ ]*100/d' /etc/gai.conf
    fi

    green "WGCF-WARP 已彻底卸载成功!"
    before_showinfo && show_info
}

# 设置 WARP-GO 配置文件
conf_wpgo() {
    echo $wpgo1 | sh
    echo $wpgo2 | sh
}

# 检测 WARP-GO 是否正常运行
check_wpgo() {
    yellow "正在启动 WARP-GO"
    i=0
    while [ $i -le 4 ]; do
        let i++
        kill -15 $(pgrep warp-go) >/dev/null 2>&1
        sleep 2
        systemctl stop warp-go
        systemctl disable warp-go >/dev/null 2>&1
        systemctl start warp-go
        systemctl enable warp-go >/dev/null 2>&1
        check_warp
        sleep 2
        if [[ $warp_v4 =~ on|plus ]] || [[ $warp_v6 =~ on|plus ]]; then
            green "WARP-GO 已启动成功！"
            echo ""
            red "下面是恰饭广告："
            yellow "灵梦机场"
            green "专线节点加速、支持流媒体解锁、支持ChatGPT、晚高峰4k秒开、大多为x0.5倍节点，这一切，仅9.9元"
            yellow "优惠尽在：https://reimu.work/auth/register?code=aKKj"
            yellow "TG群：https://t.me/ReimuCloudGrup"
            echo ""
            before_showinfo && show_info
            break
        else
            red "WARP-GO 启动失败！"
        fi

        check_warp
        if [[ ! $warp_v4 =~ on|plus && ! $warp_v6 =~ on|plus ]]; then
            systemctl stop warp-go
            systemctl disable warp-go >/dev/null 2>&1
            red "安装 WARP-GO 失败！"
            green "建议如下："
            yellow "1. 强烈建议使用官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为官方源"
            yellow "2. 部分 VPS 系统极度精简，相关依赖需自行安装后再尝试"
            yellow "3. 脚本可能跟不上时代, 建议截图发布到 GitLab Issues 或 TG 群询问"
            exit 1
        fi
    done
}

# 选择 WARP-GO 安装 / 切换模式
select_wpgo() {
    yellow "请选择 WARP-GO 安装 / 切换的模式"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 / 切换 WARP-GO 单栈模式 ${YELLOW}(IPv4)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 安装 / 切换 WARP-GO 单栈模式 ${YELLOW}(IPv6)${PLAIN}"
    echo -e " ${GREEN}3.${PLAIN} 安装 / 切换 WARP-GO 双栈模式"
    echo ""
    read -p "请输入选项 [1-3]: " wpgo_mode
    if [ "$wpgo_mode" = "1" ]; then
        install_wpgo_ipv4
    elif [ "$wpgo_mode" = "2" ]; then
        install_wpgo_ipv6
    elif [ "$wpgo_mode" = "3" ]; then
        install_wpgo_dual
    else
        red "输入错误，请重新输入"
        select_wpgo
    fi
}

install_wpgo_ipv4() {
    # 检查 WARP 状态
    check_warp

    # 如启动 WARP，则关闭
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # 因为 WARP-GO 和 WGCF 冲突，故检测 WGCF 之后打断安装
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        red "WGCF-WARP 已安装，请先卸载 WGCF-WARP"
        exit 1
    fi

    # 检查 VPS 的 IP 形式
    check_stack

    # 根据检测结果，选择适合的模式安装
    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        # IPv4 Only
        wpgo1=$wgo1 && wpgo2=$wgo4
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # IPv6 Only
        wpgo1=$wgo1 && wpgo2=$wgo5
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        # 双栈
        wpgo1=$wgo1 && wpgo2=$wgo6
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # NAT IPv4 + IPv6
        wpgo1=$wgo1 && wpgo2=$wgo6
    fi

    # 检测是否安装 WARP-GO，如安装，则切换配置文件。反之执行安装操作
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        switch_wpgo_conf
    else
        install_wpgo
    fi
}

install_wpgo_ipv6() {
    # 检查 WARP 状态
    check_warp

    # 如启动 WARP，则关闭
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # 因为 WARP-GO 和 WGCF 冲突，故检测 WGCF 之后打断安装
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        red "WGCF-WARP 已安装，请先卸载 WGCF-WARP"
        exit 1
    fi

    # 检查 VPS 的 IP 形式
    check_stack

    # 根据检测结果，选择适合的模式安装
    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        # IPv4 Only
        wpgo1=$wgo2 && wpgo2=$wgo4
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # IPv6 Only
        wpgo1=$wgo2 && wpgo2=$wgo5
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        # 双栈
        wpgo1=$wgo2 && wpgo2=$wgo6
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # NAT IPv4 + IPv6
        wpgo1=$wgo2 && wpgo2=$wgo6
    fi

    # 检测是否安装 WARP-GO，如安装，则切换配置文件。反之执行安装操作
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        switch_wpgo_conf
    else
        install_wpgo
    fi
}

install_wpgo_dual() {
    # 检查 WARP 状态
    check_warp

    # 如启动 WARP，则关闭
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # 因为 WARP-GO 和 WGCF 冲突，故检测 WGCF 之后打断安装
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        red "WGCF-WARP 已安装，请先卸载 WGCF-WARP"
        exit 1
    fi

    # 检查 VPS 的 IP 形式
    check_stack

    # 根据检测结果，选择适合的模式安装
    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        # IPv4 Only
        wpgo1=$wgo3 && wpgo2=$wgo4
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # IPv6 Only
        wpgo1=$wgo3 && wpgo2=$wgo5
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        # 双栈
        wpgo1=$wgo3 && wpgo2=$wgo6
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # NAT IPv4 + IPv6
        wpgo1=$wgo3 && wpgo2=$wgo6
    fi

    # 检测是否安装 WARP-GO，如安装，则切换配置文件。反之执行安装操作
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        switch_wpgo_conf
    else
        install_wpgo
    fi
}

install_wpgo() {
    # 检测 TUN 模块是否开启
    check_tun

    # 设置 IPv4 / IPv6 优先级
    stack_priority

    # 安装 WARP-GO 必需依赖
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget bc htop iputils screen python3 qrencode
    elif [[ $SYSTEM == "Alpine" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget bash grep bc htop iputils screen python3 qrencode
    else
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget bc htop inetutils-ping screen python3 qrencode
    fi

    # IPv4 only VPS 开启 IPv6 支持
    if [[ $(sysctl -a | grep 'disable_ipv6.*=.*1') || $(cat /etc/sysctl.{conf,d/*} | grep 'disable_ipv6.*=.*1') ]]; then
        sed -i '/disable_ipv6/d' /etc/sysctl.{conf,d/*}
        echo 'net.ipv6.conf.all.disable_ipv6 = 0' >/etc/sysctl.d/ipv6.conf
        sysctl -w net.ipv6.conf.all.disable_ipv6=0
    fi

    # 下载 WARP-GO
    mkdir -p /opt/warp-go/
    wget -O /opt/warp-go/warp-go https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-go/warp-go-latest-linux-$(archAffix)
    chmod +x /opt/warp-go/warp-go

    wget https://api.zeroteam.top/warp?format=warp-go -O /opt/warp-go/warp.conf
    chmod +x /opt/warp-go/warp.conf

    # 备用 API 注册方案
    if [[ ! -f /opt/warp-go/warp.conf ]]; then
        wget https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-api/main-linux-$(archAffix)
        chmod +x main-linux-$(archAffix)
        
        arch=$(archAffix)
        result_output=$(./main-linux-$arch)
        
        device_id=$(echo "$result_output" | awk -F ': ' '/device_id/{print $2}')
        private_key=$(echo "$result_output" | awk -F ': ' '/private_key/{print $2}')
        warp_token=$(echo "$result_output" | awk -F ': ' '/token/{print $2}')

        cat << EOF > /opt/warp-go/warp.conf
[Account]
Device = $device_id
PrivateKey = $private_key
Token = $warp_token
Type = free
Name = WARP
MTU = 1280

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
Endpoint = 162.159.192.8:0
Endpoint6 = [2606:4700:d0::a29f:c008]:0
# AllowedIPs = 0.0.0.0/0
# AllowedIPs = ::/0
KeepAlive = 30
EOF

        rm -f main-linux-$(archAffix)
    fi

    sed -i '/KeepAlive/a [Script]' /opt/warp-go/warp.conf
    
    #if [[ $country4 == "Russia" || $country6 == "Russia" ]]; then
        #wget https://api.zeroteam.top/warp?format=warp-go -O /opt/warp-go/warp.conf
        #chmod +x /opt/warp-go/warp.conf
    #else
        # 利用 WARP-GO 注册 CloudFlare WARP 账户，直到配置文件生成为止
        #until [[ -e /opt/warp-go/warp.conf ]]; do
            #yellow "正在向 CloudFlare WARP 注册账号, 如出现 Success 即为注册成功"
            #/opt/warp-go/warp-go --register --config=/opt/warp-go/warp.conf
        #done
    #fi

    # 设置 WARP-GO 的配置文件
    conf_wpgo

    # 检查最佳 MTU 值，并应用至 WARP-GO 配置文件
    check_mtu
    sed -i "s/MTU.*/MTU = $MTU/g" /opt/warp-go/warp.conf

    # 优选 EndPoint IP，并应用至 WARP-GO 配置文件
    check_endpoint
    sed -i "/Endpoint6/d" /opt/warp-go/warp.conf && sed -i "s/162.159.*/$best_endpoint/g" /opt/warp-go/warp.conf

    # 设置 WARP-GO 系统服务
    cat <<EOF >/lib/systemd/system/warp-go.service
[Unit]
Description=warp-go service
After=network.target
Documentation=https://gitlab.com/Misaka-blog/warp-script
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

    # 启动 WARP-GO，并检测 WARP-GO 是否正常运行
    check_wpgo
}

switch_wpgo_conf() {
    # 关闭 WARP-GO
    systemctl stop warp-go
    systemctl disable warp-go

    # 修改配置文件内容
    conf_wpgo

    # 检测 WARP-GO 是否正常运行
    check_wpgo
}

uninstall_wpgo() {
    # 关闭 WARP-GO
    systemctl stop warp-go
    systemctl disable --now warp-go >/dev/null 2>&1

    # 检测 WARP-GO 残留进程是否运行，如运行则杀掉
    kill -15 $(pgrep warp-go) >/dev/null 2>&1

    # 注销账户、并删除配置文件
    /opt/warp-go/warp-go --config=/opt/warp-go/warp.conf --remove >/dev/null 2>&1

    # 删除 WARP-GO 程序及日志文件
    rm -rf /opt/warp-go /tmp/warp-go* /lib/systemd/system/warp-go.service

    green "WARP-GO 已彻底卸载成功!"
}

install_warp_cli() {
    # 检测系统要求，如未达到要求则打断安装
    [[ $SYSTEM == "CentOS" ]] && [[ ! ${OSID} =~ 8|9 ]] && yellow "当前系统版本：${CMD} \nWARP-Cli代理模式仅支持CentOS / Almalinux / Rocky / Oracle Linux 8 / 9系统" && exit 1
    [[ $SYSTEM == "Debian" ]] && [[ ! ${OSID} =~ 9|10|11 ]] && yellow "当前系统版本：${CMD} \nWARP-Cli代理模式仅支持Debian 9-11系统" && exit 1
    [[ $SYSTEM == "Fedora" ]] && yellow "当前系统版本：${CMD} \nWARP-Cli暂时不支持Fedora系统" && exit 1
    [[ $SYSTEM == "Ubuntu" ]] && [[ ! ${OSID} =~ 16|18|20|22 ]] && yellow "当前系统版本：${CMD} \nWARP-Cli代理模式仅支持Ubuntu 16.04/18.04/20.04/22.04系统" && exit 1

    [[ ! $(archAffix) == "amd64" ]] && red "WARP-Cli暂时不支持目前VPS的CPU架构, 请使用CPU架构为amd64的VPS" && exit 1

    # 检测 TUN 模块是否开启
    check_tun

    # 由于 CloudFlare WARP 客户端目前只支持 AMD64 的 CPU 架构，故检测到其他架构，则打断安装
    if [[ ! $(archAffix) == "amd64" ]]; then
        red "WARP-Cli 暂时不支持目前 VPS 的 CPU 架构, 请使用 CPU 架构为 amd64 的 VPS" && exit 1
        exit 1
    fi

    # 检测 VPS 的 IP 形式，如为 IPv6 Only 的 VPS，则打断安装（啥时候 CloudFlare 发点力，支持一下又不会似一个妈）
    check_stack
    if [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        red "WARP-Cli 暂时不支持 IPv6 Only 的 VPS，请使用带有 IPv4 网络的 VPS" && exit 1
    fi

    # 安装 WARP-Cli 及其依赖
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} epel-release
        ${PACKAGE_INSTALL[int]} sudo curl wget net-tools bc htop iputils screen python3 qrencode
        rpm -ivh http://pkg.cloudflareclient.com/cloudflare-release-el8.rpm
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi
    if [[ $SYSTEM == "Debian" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release bc htop inetutils-ping screen python3 qrencode
        [[ -z $(type -P gpg 2>/dev/null) ]] && ${PACKAGE_INSTALL[int]} gnupg
        [[ -z $(apt list 2>/dev/null | grep apt-transport-https | grep installed) ]] && ${PACKAGE_INSTALL[int]} apt-transport-https
        curl https://pkg.cloudflareclient.com/pubkey.gpg | apt-key add -
        echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi
    if [[ $SYSTEM == "Ubuntu" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release bc htop inetutils-ping screen python3 qrencode
        curl https://pkg.cloudflareclient.com/pubkey.gpg | apt-key add -
        echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi

    # 询问用户 WARP-Cli 代理模式所使用的端口，如被占用则提示更换
    read -rp "请输入 WARP-Cli 代理模式所使用的端口 (默认随机端口) ：" port
    [[ -z $port ]] && port=$(shuf -i 1000-65535 -n 1)
    if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; do
            if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
                yellow "你设置的端口目前已被占用，请重新输入端口"
                read -rp "请输入 WARP-Cli 代理模式所使用的端口 (默认随机端口) ：" port
            fi
        done
    fi

    # 向 CloudFlare WARP 注册账户
    warp-cli --accept-tos register >/dev/null 2>&1

    # 在 WARP-Cli 设置代理模式和 socks5 的端口
    warp-cli --accept-tos set-mode proxy >/dev/null 2>&1
    warp-cli --accept-tos set-proxy-port "$port" >/dev/null 2>&1

    # 优选 EndPoint IP，并应用至 WARP-Cli
    check_endpoint
    warp-cli --accept-tos set-custom-endpoint "$best_endpoint" >/dev/null 2>&1

    # 启动 WARP-Cli，并检查是否正常运行
    warp-cli --accept-tos connect >/dev/null 2>&1
    warp-cli --accept-tos enable-always-on >/dev/null 2>&1
    sleep 2
    if [[ ! $(ss -nltp) =~ 'warp-svc' ]]; then
        red "WARP-Cli 代理模式安装失败"
        green "建议如下："
        yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速 ,请务必更新到最新版 ,或重置为系统官方源！"
        yellow "2. 部分 VPS 系统过于精简 ,相关依赖需自行安装后再重试"
        yellow "3. 脚本可能跟不上时代, 建议截图发布到 GitLab Issues 或 TG 群询问"
        exit 1
    else
        green "WARP-Cli 代理模式已启动成功！"
        echo ""
        red "下面是恰饭广告："
        yellow "灵梦机场"
        green "专线节点加速、支持流媒体解锁、支持ChatGPT、晚高峰4k秒开、大多为x0.5倍节点，这一切，仅9.9元"
        yellow "优惠尽在：https://reimu.work/auth/register?code=aKKj"
        yellow "TG群：https://t.me/ReimuCloudGrup"
        echo ""
        before_showinfo && show_info
    fi
}

uninstall_warp_cli() {
    # 关闭 WARP-Cli
    warp-cli --accept-tos disconnect >/dev/null 2>&1
    warp-cli --accept-tos disable-always-on >/dev/null 2>&1
    warp-cli --accept-tos delete >/dev/null 2>&1
    systemctl disable --now warp-svc >/dev/null 2>&1

    # 卸载 WARP-Cli
    ${PACKAGE_UNINSTALL[int]} cloudflare-warp

    green "WARP-Cli客户端已彻底卸载成功!"
    before_showinfo && show_info
}

install_wireproxy() {
    # 安装 WireProxy 依赖
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget bc htop iputils screen python3 qrencode
    elif [[ $SYSTEM == "Alpine" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget bash grep bc htop iputils screen python3 qrencode
    else
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget bc htop inetutils-ping screen python3 qrencode
    fi

    # 下载 WireProxy
    wget -N https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/wireproxy/wireproxy-latest-linux-$(archAffix) -O /usr/local/bin/wireproxy
    chmod +x /usr/local/bin/wireproxy

    # 询问用户 WireProxy 所使用的端口，如被占用则提示更换
    read -rp "请输入 WireProxy-WARP 代理模式所使用的端口 (默认随机端口) ：" port
    [[ -z $port ]] && port=$(shuf -i 1000-65535 -n 1)
    if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; do
            if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
                yellow "你设置的端口目前已被占用，请重新输入端口"
                read -rp "请输入 WireProxy-WARP 代理模式所使用的端口 (默认随机端口) ：" port
            fi
        done
    fi

    # 下载并安装 WGCF
    init_wgcf

    # 利用 WGCF，向 CloudFlare WARP 注册账户
    register_wgcf

    # 提取 WGCF 配置文件的公私钥
    public_key=$(grep PublicKey wgcf-profile.conf | sed "s/PublicKey = //g")
    private_key=$(grep PrivateKey wgcf-profile.conf | sed "s/PrivateKey = //g")

    # 检测 /etc/wireguard 文件夹是否创建，如未创建则创建一个
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
    fi

    # 先关闭 WGCF 或者是 WARP-GO（如有），以免影响检查最佳 MTU 值及优选 EndPoint IP
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # 检查最佳 MTU 值
    check_mtu

    # 优选 EndPoint IP
    check_endpoint

    # 启动 WGCF 或者是 WARP-GO（如有）
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl start warp-go
        systemctl enable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick up wgcf >/dev/null 2>&1
        systemctl enable wg-quick@wgcf
    fi

    # 应用 WireProxy 配置文件，并将 WGCF 配置文件移至 /etc/wireguard 文件夹，以备安装 WGCF-WARP 使用
    cat <<EOF >/etc/wireguard/proxy.conf
[Interface]
Address = 172.16.0.2/32
MTU = $MTU
PrivateKey = $private_key
DNS = 1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4,2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860::8844
[Peer]
PublicKey = $public_key
Endpoint = $best_endpoint
[Socks5]
BindAddress = 127.0.0.1:$port
EOF
    mv -f wgcf-profile.conf /etc/wireguard/wgcf-profile.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml

    # 设置 WireProxy 系统服务
    cat <<'TEXT' >/etc/systemd/system/wireproxy-warp.service
[Unit]
Description=CloudFlare WARP Socks5 proxy mode based for WireProxy, script by Misaka-blog
After=network.target
[Install]
WantedBy=multi-user.target
[Service]
Type=simple
WorkingDirectory=/root
ExecStart=/usr/local/bin/wireproxy -c /etc/wireguard/proxy.conf
Restart=always
TEXT

    # 启动 WireProxy，并检查是否正常运行
    yellow "正在启动 WireProxy-WARP 代理模式"
    systemctl start wireproxy-warp
    wireproxy_status=$(curl -sx socks5h://localhost:$port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
    sleep 2
    retry_time=0
    until [[ $wireproxy_status =~ on|plus ]]; do
        retry_time=$((${retry_time} + 1))
        red "启动 WireProxy-WARP 代理模式失败，正在尝试重启，重试次数：$retry_time"
        systemctl stop wireproxy-warp
        systemctl start wireproxy-warp
        wireproxy_status=$(curl -sx socks5h://localhost:$port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        if [[ $retry_time == 6 ]]; then
            echo ""
            red "安装 WireProxy-WARP 代理模式失败！"
            green "建议如下："
            yellow "1. 强烈建议使用官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为官方源"
            yellow "2. 部分 VPS 系统极度精简，相关依赖需自行安装后再尝试"
            yellow "3. 查看 https://www.cloudflarestatus.com/ ，你当前VPS就近区域可能处于黄色的【Re-routed】状态"
            yellow "4. WGCF 在香港、美西区域遭到 CloudFlare 官方封禁"
            yellow "5. 脚本可能跟不上时代, 建议截图发布到 GitLab Issues 或 TG 群询问"
            exit 1
        fi
        sleep 8
    done
    sleep 5
    systemctl enable wireproxy-warp >/dev/null 2>&1
    green "WireProxy-WARP 代理模式已启动成功!"
    echo ""
    red "下面是恰饭广告："
    yellow "灵梦机场"
    green "专线节点加速、支持流媒体解锁、支持ChatGPT、晚高峰4k秒开、大多为x0.5倍节点，这一切，仅9.9元"
    yellow "优惠尽在：https://reimu.work/auth/register?code=aKKj"
    yellow "TG群：https://t.me/ReimuCloudGrup"
    echo ""
    before_showinfo && show_info
}

uninstall_wireproxy() {
    # 关闭 WireProxy
    systemctl stop wireproxy-warp
    systemctl disable wireproxy-warp

    # 删除 WireProxy 程序文件
    rm -f /etc/systemd/system/wireproxy-warp.service /usr/local/bin/wireproxy /etc/wireguard/proxy.conf

    # 如未安装 WGCF-WARP，则删除 WGCF 账户信息及配置文件
    if [[ ! -f /etc/wireguard/wgcf.conf ]]; then
        rm -f /usr/local/bin/wgcf /etc/wireguard/wgcf-account.toml
    fi

    green "WireProxy-WARP代理模式已彻底卸载成功!"
    before_showinfo && show_info
}

change_warp_port() {
    yellow "请选择需要修改端口的 WARP 客户端"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} WARP-Cli"
    echo -e " ${GREEN}2.${PLAIN} WireProxy"
    echo ""
    read -p "请输入选项 [1-2]: " chport_mode
    if [[ $chport_mode == 1 ]]; then
        # 如 WARP-Cli 正在启动，则关闭
        if [[ $(warp-cli --accept-tos status) =~ Connected ]]; then
            warp-cli --accept-tos disconnect >/dev/null 2>&1
        fi

        # 询问用户 WARP-Cli 代理模式所使用的端口，如被占用则提示更换
        read -rp "请输入 WARP-Cli 代理模式所使用的端口 (默认随机端口) ：" port
        [[ -z $port ]] && port=$(shuf -i 1000-65535 -n 1)
        if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
            until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; do
                if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
                    yellow "你设置的端口目前已被占用，请重新输入端口"
                    read -rp "请输入 WARP-Cli 代理模式所使用的端口 (默认随机端口) ：" port
                fi
            done
        fi

        # 设置 WARP-Cli 代理模式所使用的端口
        warp-cli --accept-tos set-proxy-port "$port" >/dev/null 2>&1

        # 启动 WARP-Cli，并检查是否正常运行
        warp-cli --accept-tos connect >/dev/null 2>&1
        warp-cli --accept-tos enable-always-on >/dev/null 2>&1
        sleep 2
        if [[ ! $(ss -nltp) =~ 'warp-svc' ]]; then
            red "WARP-Cli 代理模式安装失败"
            green "建议如下："
            yellow "1. 建议使用系统官方源升级系统及内核加速！如已使用第三方源及内核加速 ,请务必更新到最新版 ,或重置为系统官方源！"
            yellow "2. 部分 VPS 系统过于精简 ,相关依赖需自行安装后再重试"
            yellow "3. 脚本可能跟不上时代, 建议截图发布到 GitLab Issues 或 TG 群询问"
            exit 1
        else
            green "WARP-Cli 代理模式已启动成功！"
            before_showinfo && show_info
        fi
    elif [[ $chport_mode == 2 ]]; then
        # 如 WireProxy 正在启动，则关闭
        if [[ -n $(ss -nltp | grep wireproxy) ]]; then
            systemctl stop wireproxy-warp
        fi

        # 询问用户 WireProxy 所使用的端口，如被占用则提示更换
        read -rp "请输入 WireProxy-WARP 代理模式所使用的端口 (默认随机端口) ：" port
        [[ -z $port ]] && port=$(shuf -i 1000-65535 -n 1)
        if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
            until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; do
                if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
                    yellow "你设置的端口目前已被占用，请重新输入端口"
                    read -rp "请输入 WireProxy-WARP 代理模式所使用的端口 (默认随机端口) ：" port
                fi
            done
        fi

        # 获取当前 WireProxy 的 socks5 端口
        current_port=$(grep BindAddress /etc/wireguard/proxy.conf)
        sed -i "s/$current_port/BindAddress = 127.0.0.1:$port/g" /etc/wireguard/proxy.conf

        # 启动 WireProxy，并检查是否正常运行
        yellow "正在启动 WireProxy-WARP 代理模式"
        systemctl start wireproxy-warp
        wireproxy_status=$(curl -sx socks5h://localhost:$port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        sleep 2
        retry_time=0
        until [[ $wireproxy_status =~ on|plus ]]; do
            retry_time=$((${retry_time} + 1))
            red "启动 WireProxy-WARP 代理模式失败，正在尝试重启，重试次数：$retry_time"
            systemctl stop wireproxy-warp
            systemctl start wireproxy-warp
            wireproxy_status=$(curl -sx socks5h://localhost:$port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
            if [[ $retry_time == 6 ]]; then
                echo ""
                red "安装 WireProxy-WARP 代理模式失败！"
                green "建议如下："
                yellow "1. 强烈建议使用官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为官方源"
                yellow "2. 部分 VPS 系统极度精简，相关依赖需自行安装后再尝试"
                yellow "3. 查看 https://www.cloudflarestatus.com/ ，你当前VPS就近区域可能处于黄色的【Re-routed】状态"
                yellow "4. WGCF 在香港、美西区域遭到 CloudFlare 官方封禁"
                yellow "5. 脚本可能跟不上时代, 建议截图发布到 GitLab Issues 或 TG 群询问"
                exit 1
            fi
            sleep 8
        done
        sleep 5
        systemctl enable wireproxy-warp >/dev/null 2>&1
        green "WireProxy-WARP 代理模式已启动成功!"
        before_showinfo && show_info
    else
        red "输入错误，请重新输入"
        change_warp_port
    fi
}

switch_warp() {
    yellow "请选择需要修改端口的 WARP 客户端"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 启动 WGCF-WARP"
    echo -e " ${GREEN}2.${PLAIN} 关闭 WGCF-WARP"
    echo -e " ${GREEN}3.${PLAIN} 重启 WGCF-WARP"
    echo -e " ${GREEN}4.${PLAIN} 启动 WARP-GO"
    echo -e " ${GREEN}5.${PLAIN} 关闭 WARP-GO"
    echo -e " ${GREEN}6.${PLAIN} 重启 WARP-GO"
    echo -e " ${GREEN}7.${PLAIN} 启动 WARP-Cli"
    echo -e " ${GREEN}8.${PLAIN} 关闭 WARP-Cli"
    echo -e " ${GREEN}9.${PLAIN} 重启 WARP-Cli"
    echo -e " ${GREEN}10.${PLAIN} 启动 WireProxy-WARP"
    echo -e " ${GREEN}11.${PLAIN} 关闭 WireProxy-WARP"
    echo -e " ${GREEN}12.${PLAIN} 重启 WireProxy-WARP"
    echo ""
    read -rp "请输入选项 [0-12]: " switch_input
    case $switch_input in
    1)
        systemctl start wg-quick@wgcf >/dev/null 2>&1
        systemctl enable wg-quick@wgcf >/dev/null 2>&1
        ;;
    2)
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf >/dev/null 2>&1
        ;;
    3)
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf >/dev/null 2>&1
        systemctl start wg-quick@wgcf >/dev/null 2>&1
        systemctl enable wg-quick@wgcf >/dev/null 2>&1
        ;;
    4)
        systemctl start warp-go
        systemctl enable warp-go >/dev/null 2>&1
        ;;
    5)
        systemctl stop warp-go
        systemctl disable warp-go >/dev/null 2>&1
        ;;
    6)
        systemctl stop warp-go
        systemctl disable warp-go >/dev/null 2>&1
        systemctl start warp-go
        systemctl enable warp-go >/dev/null 2>&1
        ;;
    7)
        warp-cli --accept-tos connect >/dev/null 2>&1
        warp-cli --accept-tos enable-always-on >/dev/null 2>&1
        ;;
    8) warp-cli --accept-tos disconnect >/dev/null 2>&1 ;;
    9)
        warp-cli --accept-tos disconnect >/dev/null 2>&1
        warp-cli --accept-tos connect >/dev/null 2>&1
        warp-cli --accept-tos enable-always-on >/dev/null 2>&1
        ;;
    10)
        systemctl start wireproxy-warp
        systemctl enable wireproxy-warp
        ;;
    11)
        systemctl stop wireproxy-warp
        systemctl disable wireproxy-warp
        ;;
    12)
        systemctl stop wireproxy-warp
        systemctl disable wireproxy-warp
        systemctl start wireproxy-warp
        systemctl enable wireproxy-warp
        ;;
    *) exit 1 ;;
    esac
}

wireguard_profile() {
    yellow "请选择需要从哪个 WARP 客户端生成 WireGuard 配置文件"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} WARP-GO"
    echo -e " ${GREEN}2.${PLAIN} WGCF"
    echo ""
    read -p "请输入选项 [1-2]: " profile_mode
    if [[ $profile_mode == 1 ]]; then
        # 调用 WARP-GO 的接口，生成 WireGuard 配置文件，并判断生成状态
        result=$(/opt/warp-go/warp-go --config=/opt/warp-go/warp.conf --export-wireguard=/root/warpgo-proxy.conf) && sleep 5
        if [[ ! $result == "Success" ]]; then
            red "WARP-GO 的 WireGuard 配置文件生成失败！"
            exit 1
        fi

        # 调用 WARP-GO 的接口，生成 Sing-box 配置文件，并判断生成状态
        result=$(/opt/warp-go/warp-go --config=/opt/warp-go/warp.conf --export-singbox=/root/warpgo-sing-box.json) && sleep 5
        if [[ ! $result == "Success" ]]; then
            red "WARP-GO 的 Sing-box 配置文件生成失败！"
            exit 1
        fi

        # 用户回显、以及生成二维码
        green "WARP-GO 的 WireGuard 配置文件已提取成功！"
        yellow "文件内容如下，并已保存至：/root/warpgo-proxy.conf"
        red "$(cat /root/warpgo-proxy.conf)"
        echo ""
        yellow "节点配置二维码如下所示："
        qrencode -t ansiutf8 </root/warpgo-proxy.conf
        echo ""
        echo ""
        green "WARP-GO 的 Sing-box 配置文件已提取成功！"
        yellow "文件内容如下，并已保存至：/root/warpgo-sing-box.json"
        red "$(cat /root/warpgo-sing-box.json)"
        yellow "Reserved 值：$(grep -o '"reserved":\[[^]]*\]' /root/warpgo-sing-box.json)"
        echo ""
        yellow "请在本地使用此方法：https://blog.misaka.rest/2023/03/12/cf-warp-yxip/ 优选可用的 Endpoint IP"
    elif [[ $profile_mode == 2 ]]; then
        # 复制 WGCF 配置文件
        cp -f /etc/wireguard/wgcf-profile.conf /root/wgcf-proxy.conf

        # 用户回显、以及生成二维码
        green "WGCF-WARP 的 WireGuard 配置文件已提取成功！"
        yellow "文件内容如下，并已保存至：/root/wgcf-proxy.conf"
        red "$(cat /root/wgcf-proxy.conf)"
        echo ""
        yellow "节点配置二维码如下所示："
        qrencode -t ansiutf8 </root/wgcf-proxy.conf
        echo ""
        yellow "请在本地使用此方法：https://blog.misaka.rest/2023/03/12/cf-warp-yxip/ 优选可用的 Endpoint IP"
    else
        red "输入错误，请重新输入"
        wireguard_profile
    fi
}

warp_traffic() {
    if [[ -z $(type -P screen) ]]; then
        if [[ ! $SYSTEM == "CentOS" ]]; then
            ${PACKAGE_UPDATE[int]}
        fi
        ${PACKAGE_INSTALL[int]} screen
    fi

    yellow "获取自己的 CloudFlare WARP 账号信息方法: "
    green "电脑: 下载并安装 CloudFlare WARP → 设置 → 偏好设置 → 复制设备ID到脚本中"
    green "手机: 下载并安装 1.1.1.1 APP → 菜单 → 高级 → 诊断 → 复制设备ID到脚本中"
    echo ""
    yellow "请按照下面指示, 输入您的 CloudFlare WARP 账号信息:"
    read -rp "请输入您的 WARP 设备 ID (36位字符): " license
    until [[ $license =~ ^[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}$ ]]; do
        red "设备 ID 输入格式输入错误，请重新输入！"
        read -rp "请输入您的 WARP 设备 ID (36位字符): " license
    done

    wget -N --no-check-certificate https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/wp-plus.py
    sed -i "27 s/[(][^)]*[)]//g" wp-plus.py && sed -i "27 s/input/'$license'/" wp-plus.py

    read -rp "请输入 Screen 会话名称 (默认为wp-plus): " screenname
    [[ -z $screenname ]] && screenname="wp-plus"
    screen -UdmS $screenname bash -c '/usr/bin/python3 /root/wp-plus.py'

    green "创建刷 WARP+ 流量任务成功！ Screen会话名称为：$screenname"
}

wgcf_account() {
    yellow "请选择需要切换的 WARP 账户类型"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} WARP 免费账户 ${YELLOW}(默认)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} WARP+"
    echo -e " ${GREEN}3.${PLAIN} WARP Teams"
    echo ""
    read -p "请输入选项 [1-3]: " account_type
    if [[ $account_type == 2 ]]; then
        # 关闭 WGCF
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf >/dev/null 2>&1

        # 询问用户获取 WARP 账户许可证密钥，并应用到 WARP 账户配置文件中
        yellow "获取CloudFlare WARP账号密钥信息方法: "
        green "电脑: 下载并安装CloudFlare WARP → 设置 → 偏好设置 → 账户 → 复制密钥到脚本中"
        green "手机: 下载并安装1.1.1.1 APP → 菜单 → 账户 → 复制密钥到脚本中"
        echo ""
        yellow "重要：请确保手机或电脑的1.1.1.1 APP的账户状态为WARP+！"
        read -rp "输入 WARP 账户许可证密钥 (26个字符): " warpkey
        until [[ -z $warpkey || $warpkey =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}$ ]]; do
            red "WARP 账户许可证密钥格式输入错误，请重新输入！"
            read -rp "输入 WARP 账户许可证密钥 (26个字符): " warpkey
        done
        sed -i "s/license_key.*/license_key = \"$warpkey\"/g" wgcf-account.toml

        # 删除原来的 WireGuard 配置文件
        rm -rf /etc/wireguard/wgcf-profile.conf

        # 询问用户是否使用自定义设备名称，如未使用则使用 WGCF 随机生成的六位设备名
        read -rp "请输入自定义设备名，如未输入则使用默认随机设备名: " device_name
        if [[ -n $device_name ]]; then
            wgcf update --name $(echo $device_name | sed s/[[:space:]]/_/g) > /etc/wireguard/info.log 2>&1
        else
            wgcf update > /etc/wireguard/info.log 2>&1
        fi

        # 生成新的 WireGuard 配置文件
        wgcf generate

        # 获取私钥以及 IPv6 内网地址，用于替换 wgcf.conf 文件中对应的内容
        private_v6=$(cat /etc/wireguard/wgcf-profile.conf | sed -n 4p | sed "s/Address = //g")
        private_key=$(grep PrivateKey /etc/wireguard/wgcf-profile.conf | sed "s/PrivateKey = //g")
        sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/wgcf.conf;
        sed -i "s#Address.*128#Address = $private_v6#g" /etc/wireguard/wgcf.conf;

        # 启动 WGCF，并检查 WGCF 是否启动成功
        check_wgcf
    elif [[ $account_type == 3 ]]; then
        # 关闭 WGCF
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf >/dev/null 2>&1

        yellow "请选择申请 WARP Teams 账户方式"
        echo ""
        echo -e " ${GREEN}1.${PLAIN} 使用 Teams TOKEN ${YELLOW}(默认)${PLAIN}"
        echo -e " ${GREEN}2.${PLAIN} 使用提取出来的 xml 配置文件"
        echo ""
        read -p "请输入选项 [1-2]: " team_type

        if [[ $team_type == 2 ]]; then
            # 询问用户获取 WARP Teams 账户 xml 文件配置链接，并提示获取方式及上传方法
            yellow "获取 WARP Teams 账户 xml 配置文件方法：https://blog.misaka.rest/2023/02/11/wgcfteam-config/"
            yellow "请将提取到的 xml 配置文件上传至：https://gist.github.com"
            read -rp "请粘贴 WARP Teams 账户配置文件链接：" teamconfigurl
            if [[ -n $teamconfigurl ]]; then
                # 将一些字符过滤，以便脚本识别出内容
                teams_config=$(curl -sSL "$teamconfigurl" | sed "s/\"/\&quot;/g")

                # 获取私钥以及 IPv6 内网地址，用于替换 wgcf.conf 和 wgcf-profile.conf 文件中对应的内容
                private_key=$(expr "$teams_config" : '.*private_key&quot;>\([^<]*\).*')
                private_v6=$(expr "$teams_config" : '.*v6&quot;:&quot;\([^[&]*\).*')
                sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/wgcf.conf;
                sed -i "s#Address.*128#Address = $private_v6#g" /etc/wireguard/wgcf.conf;
                sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/wgcf-profile.conf;
                sed -i "s#Address.*128#Address = $private_v6#g" /etc/wireguard/wgcf-profile.conf;

                # 启动 WGCF，并检查 WGCF 是否启动成功
                check_wgcf
            else
                red "未提供WARP Teams 账户配置文件链接，脚本退出！"
                exit 1
            fi
        else
            # 询问用户 WARP Teams 账户 TOKEN，并提示获取方式
            yellow "请在此网站：https://web--public--warp-team-api--coia-mfs4.code.run/ 获取你的 WARP Teams 账户 TOKEN"
            read -rp "请输入 WARP Teams 账户的 TOKEN：" teams_token

            if [[ -n $teams_token ]]; then
                # 生成 WireGuard 公私钥及 WARP 设备 ID 和 FCM Token
                private_key=$(wg genkey)
                public_key=$(wg pubkey <<< "$private_key")
                install_id=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 22)
                fcm_token="${install_id}:APA91b$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 134)"

                # 使用 CloudFlare API 申请 Teams 配置信息
                team_result=$(curl --silent --location --tlsv1.3 --request POST 'https://api.cloudflareclient.com/v0a2158/reg' \
                --header 'User-Agent: okhttp/3.12.1' \
                --header 'CF-Client-Version: a-6.10-2158' \
                --header 'Content-Type: application/json' \
                --header "Cf-Access-Jwt-Assertion: ${TEAM_TOKEN}" \
                --data '{"key":"'${public_key}'","install_id":"'${install_id}'","fcm_token":"'${fcm_token}'","tos":"'$(date +"%Y-%m-%dT%H:%M:%S.%3NZ")'","model":"Linux","serial_number":"'${install_id}'","locale":"zh_CN"}')

                # 提取 WARP IPv6 内网地址，用于替换 wgcf.conf 和 wgcf-profile.conf 文件中对应的内容
                private_v6=$(expr "$team_result" : '.*"v6":[ ]*"\([^"]*\).*')

                sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/wgcf.conf;
                sed -i "s#Address.*128#Address = $private_v6#g" /etc/wireguard/wgcf.conf;
                sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/wgcf-profile.conf;
                sed -i "s#Address.*128#Address = $private_v6#g" /etc/wireguard/wgcf-profile.conf;

                # 启动 WGCF，并检查 WGCF 是否启动成功
                check_wgcf
            else
                red "未输入 WARP Teams 账户 TOKEN，脚本退出！"
                exit 1
            fi
        fi
    else
        # 关闭 WGCF
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf >/dev/null 2>&1

        # 删除原来的账号及 WireGuard 配置文件
        rm -f /etc/wireguard/wgcf-account.toml /etc/wireguard/wgcf-profile.conf

        # 在 WGCF 处注册账户
        register_wgcf

        # 移动新的账号及 WireGuard 配置文件
        mv -f wgcf-profile.conf /etc/wireguard/wgcf-profile.conf
        mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml

        # 获取私钥以及 IPv6 内网地址，用于替换 wgcf.conf 文件中对应的内容
        private_v6=$(cat /etc/wireguard/wgcf-profile.conf | sed -n 4p | sed "s/Address = //g")
        private_key=$(grep PrivateKey /etc/wireguard/wgcf-profile.conf | sed "s/PrivateKey = //g")
        sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/wgcf.conf;
        sed -i "s#Address.*128#Address = $private_v6/128#g" /etc/wireguard/wgcf.conf;

        # 启动 WGCF，并检查 WGCF 是否启动成功
        check_wgcf
    fi
}

wpgo_account() {
    # 检查 VPS 的 IP 形式（如有 WARP 开启则关闭，待检测完再开）
    check_warp
    if [[ $warp_v4 =~ on|plus ]] || [[ $warp_v6 =~ on|plus ]]; then
        systemctl stop warp-go
        check_stack
        systemctl start warp-go
    else
        check_stack
    fi

    # 获取并设置目前 WARP-GO 文件的 IP 出站、允许外部 IP 信息，备用
    current_allowips=$(cat /opt/warp-go/warp.conf | grep AllowedIPs)
    [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]] && current_postip=$wgo4
    [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]] && current_postip=$wgo5
    [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]] && current_postip=$wgo6
    [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]] && current_postip=$wgo6

    yellow "请选择需要切换的 WARP 账户类型"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} WARP 免费账户 ${YELLOW}(默认)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} WARP+"
    echo -e " ${GREEN}3.${PLAIN} WARP Teams"
    echo ""
    read -p "请输入选项 [1-3]: " account_type

    if [[ $account_type == 2 ]]; then
        # 关闭 WARP-GO
        systemctl stop warp-go

        # 询问用户获取 WARP 账户许可证密钥
        yellow "获取CloudFlare WARP账号密钥信息方法: "
        green "电脑: 下载并安装CloudFlare WARP → 设置 → 偏好设置 → 账户 → 复制密钥到脚本中"
        green "手机: 下载并安装1.1.1.1 APP → 菜单 → 账户 → 复制密钥到脚本中"
        echo ""
        yellow "重要：请确保手机或电脑的1.1.1.1 APP的账户状态为WARP+！"
        read -rp "输入 WARP 账户许可证密钥 (26个字符): " warpkey
        until [[ -z $warpkey || $warpkey =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}$ ]]; do
            red "WARP 账户许可证密钥格式输入错误，请重新输入！"
            read -rp "输入 WARP 账户许可证密钥 (26个字符): " warpkey
        done

        # 询问用户是否使用自定义设备名称，如未使用则使用 WARP-GO 随机生成的六位设备名
        read -rp "请输入自定义设备名，如未输入则使用默认随机设备名: " device_name
        [[ -z $device_name ]] && device_name=$(date +%s%N | md5sum | cut -c 1-6)

        # 使用 WARP+ 账户密钥，升级原有的配置文件
        result=$(/opt/warp-go/warp-go --update --config=/opt/warp-go/warp.conf --license=$warpkey --device-name=$devicename)

        # 判断是否升级成功，如果失败则还原 WARP 免费版账户
        if [[ $result == "Success" ]]; then
            # 应用 WARP-GO 配置
            sed -i "s#.*AllowedIPs.*#$current_allowips#g" /opt/warp-go/warp.conf
            echo $current_postip | sh

            # 检查最佳 MTU 值，并应用至 WARP-GO 配置文件
            check_mtu
            sed -i "s/MTU.*/MTU = $MTU/g" /opt/warp-go/warp.conf

            # 优选 EndPoint IP，并应用至 WARP-GO 配置文件
            check_endpoint
            sed -i "/Endpoint6/d" /opt/warp-go/warp.conf && sed -i "s/162.159.*/$best_endpoint/g" /opt/warp-go/warp.conf
            
            # 启动 WARP-GO，并检测 WARP-GO 是否正常运行
            check_wpgo
        else
            red "WARP+ 账户注册失败！正在还原为 WARP 免费账户"

            # 关闭 WARP-GO
            systemctl stop warp-go

            # 删除原来的配置文件，并重新注册
            rm -f /opt/warp-go/warp.conf
            wget https://api.zeroteam.top/warp?format=warp-go -O /opt/warp-go/warp.conf
            chmod +x /opt/warp-go/warp.conf

            # 应用 WARP-GO 配置
            sed -i "s#.*AllowedIPs.*#$current_allowips#g" /opt/warp-go/warp.conf
            echo $current_postip | sh

            # 检查最佳 MTU 值，并应用至 WARP-GO 配置文件
            check_mtu
            sed -i "s/MTU.*/MTU = $MTU/g" /opt/warp-go/warp.conf

            # 优选 EndPoint IP，并应用至 WARP-GO 配置文件
            check_endpoint
            sed -i "/Endpoint6/d" /opt/warp-go/warp.conf && sed -i "s/162.159.*/$best_endpoint/g" /opt/warp-go/warp.conf
            
            # 启动 WARP-GO，并检测 WARP-GO 是否正常运行
            check_wpgo
        fi
    elif [[ $account_type == 3 ]]; then
        # 关闭 WARP-GO
        systemctl stop warp-go

        # 询问用户 WARP Teams 账户 TOKEN，并提示获取方式
        yellow "请在此网站：https://web--public--warp-team-api--coia-mfs4.code.run/ 获取你的 WARP Teams 账户 TOKEN"
        read -rp "请输入 WARP Teams 账户的 TOKEN：" teams_token

        if [[ -n $teams_token ]]; then
            # 询问用户是否使用自定义设备名称，如未使用则使用 WARP-GO 随机生成的六位设备名
            read -rp "请输入自定义设备名，如未输入则使用默认随机设备名: " device_name
            [[ -z $device_name ]] && device_name=$(date +%s%N | md5sum | cut -c 1-6)

            # 使用 Teams TOKEN 升级配置文件
            /opt/warp-go/warp-go --update --config=/opt/warp-go/warp.conf --team-config=$teams_token --device-name=$device_name

            # 应用 WARP-GO 配置
            sed -i "s#.*AllowedIPs.*#$current_allowips#g" /opt/warp-go/warp.conf
            echo $current_postip | sh

            # 检查最佳 MTU 值，并应用至 WARP-GO 配置文件
            check_mtu
            sed -i "s/MTU.*/MTU = $MTU/g" /opt/warp-go/warp.conf

            # 优选 EndPoint IP，并应用至 WARP-GO 配置文件
            check_endpoint
            sed -i "/Endpoint6/d" /opt/warp-go/warp.conf && sed -i "s/162.159.*/$best_endpoint/g" /opt/warp-go/warp.conf
            
            # 启动 WARP-GO，并检测 WARP-GO 是否正常运行
            check_wpgo
        else
            red "未输入 WARP Teams 账户 TOKEN，脚本退出！"
            exit 1
        fi
    else
        # 关闭 WARP-GO
        systemctl stop warp-go

        # 删除原来的配置文件，并重新注册
        rm -f /opt/warp-go/warp.conf
        
        wget https://api.zeroteam.top/warp?format=warp-go -O /opt/warp-go/warp.conf
        chmod +x /opt/warp-go/warp.conf

        # 应用 WARP-GO 配置
        sed -i "s#.*AllowedIPs.*#$current_allowips#g" /opt/warp-go/warp.conf
        echo $current_postip | sh

        # 检查最佳 MTU 值，并应用至 WARP-GO 配置文件
        check_mtu
        sed -i "s/MTU.*/MTU = $MTU/g" /opt/warp-go/warp.conf

        # 优选 EndPoint IP，并应用至 WARP-GO 配置文件
        check_endpoint
        sed -i "/Endpoint6/d" /opt/warp-go/warp.conf && sed -i "s/162.159.*/$best_endpoint/g" /opt/warp-go/warp.conf
            
        # 启动 WARP-GO，并检测 WARP-GO 是否正常运行
        check_wpgo
    fi
}

warp_cli_account() {
    # 关闭 WARP-Cli
    warp-cli --accept-tos disconnect >/dev/null 2>&1
    warp-cli --accept-tos register >/dev/null 2>&1

    # 询问用户获取 WARP 账户许可证密钥
    yellow "获取CloudFlare WARP账号密钥信息方法: "
    green "电脑: 下载并安装CloudFlare WARP → 设置 → 偏好设置 → 账户 → 复制密钥到脚本中"
    green "手机: 下载并安装1.1.1.1 APP → 菜单 → 账户 → 复制密钥到脚本中"
    echo ""
    yellow "重要：请确保手机或电脑的1.1.1.1 APP的账户状态为WARP+！"
    read -rp "输入 WARP 账户许可证密钥 (26个字符): " warpkey
    until [[ -z $warpkey || $warpkey =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}$ ]]; do
        red "WARP 账户许可证密钥格式输入错误，请重新输入！"
        read -rp "输入 WARP 账户许可证密钥 (26个字符): " warpkey
    done

    # 设置 WARP 账户许可证密钥并连接
    warp-cli --accept-tos set-license "$warpkey" >/dev/null 2>&1 && sleep 1
    warp-cli --accept-tos connect >/dev/null 2>&1

    # 检查账户是否升级成功，如未升级成功则提示使用免费账户
    if [[ $(warp-cli --accept-tos account) =~ Limited ]]; then
        green "WARP-Cli 账户类型切换为 WARP+ 成功！"
    else
        red "WARP+ 账户启用失败, 已自动降级至 WARP 免费版账户"
    fi
}

wireproxy_account() {
    yellow "请选择需要切换的 WARP 账户类型"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} WARP 免费账户 ${YELLOW}(默认)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} WARP+"
    echo -e " ${GREEN}3.${PLAIN} WARP Teams"
    echo ""
    read -p "请输入选项 [1-3]: " account_type
    if [[ $account_type == 2 ]]; then
        # 关闭 WireProxy
        systemctl stop wireproxy-warp
        systemctl disable wireproxy-warp

        # 询问用户获取 WARP 账户许可证密钥，并应用到 WARP 账户配置文件中
        yellow "获取CloudFlare WARP账号密钥信息方法: "
        green "电脑: 下载并安装CloudFlare WARP → 设置 → 偏好设置 → 账户 → 复制密钥到脚本中"
        green "手机: 下载并安装1.1.1.1 APP → 菜单 → 账户 → 复制密钥到脚本中"
        echo ""
        yellow "重要：请确保手机或电脑的1.1.1.1 APP的账户状态为WARP+！"
        read -rp "输入 WARP 账户许可证密钥 (26个字符): " warpkey
        until [[ -z $warpkey || $warpkey =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}$ ]]; do
            red "WARP 账户许可证密钥格式输入错误，请重新输入！"
            read -rp "输入 WARP 账户许可证密钥 (26个字符): " warpkey
        done
        sed -i "s/license_key.*/license_key = \"$warpkey\"/g" wgcf-account.toml

        # 删除原来的 WireGuard 配置文件
        rm -rf /etc/wireguard/wgcf-profile.conf

        # 询问用户是否使用自定义设备名称，如未使用则使用 WGCF 随机生成的六位设备名
        read -rp "请输入自定义设备名，如未输入则使用默认随机设备名: " device_name
        if [[ -n $device_name ]]; then
            wgcf update --name $(echo $device_name | sed s/[[:space:]]/_/g) > /etc/wireguard/info.log 2>&1
        else
            wgcf update > /etc/wireguard/info.log 2>&1
        fi

        # 生成新的 WireGuard 配置文件
        wgcf generate

        # 获取私钥以及 IPv6 内网地址，用于替换 proxy.conf 文件中对应的内容
        private_key=$(grep PrivateKey /etc/wireguard/wgcf-profile.conf | sed "s/PrivateKey = //g")
        sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/proxy.conf;

        # 启动 WireProxy，并检查是否正常运行
        yellow "正在启动 WireProxy-WARP 代理模式"
        systemctl start wireproxy-warp
        wireproxy_status=$(curl -sx socks5h://localhost:$port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        sleep 2
        retry_time=0
        until [[ $wireproxy_status =~ on|plus ]]; do
            retry_time=$((${retry_time} + 1))
            red "启动 WireProxy-WARP 代理模式失败，正在尝试重启，重试次数：$retry_time"
            systemctl stop wireproxy-warp
            systemctl start wireproxy-warp
            wireproxy_status=$(curl -sx socks5h://localhost:$port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
            if [[ $retry_time == 6 ]]; then
                echo ""
                red "安装 WireProxy-WARP 代理模式失败！"
                green "建议如下："
                yellow "1. 强烈建议使用官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为官方源"
                yellow "2. 部分 VPS 系统极度精简，相关依赖需自行安装后再尝试"
                yellow "3. 查看 https://www.cloudflarestatus.com/ ，你当前VPS就近区域可能处于黄色的【Re-routed】状态"
                yellow "4. WGCF 在香港、美西区域遭到 CloudFlare 官方封禁"
                yellow "5. 脚本可能跟不上时代, 建议截图发布到 GitLab Issues 或 TG 群询问"
                exit 1
            fi
            sleep 8
        done
        sleep 5
        systemctl enable wireproxy-warp >/dev/null 2>&1
        green "WireProxy-WARP 代理模式已启动成功!"
        before_showinfo && show_info
    elif [[ $account_type == 3 ]]; then
        # 关闭 WireProxy
        systemctl stop wireproxy-warp
        systemctl disable wireproxy-warp

        # 询问用户获取 WARP Teams 账户 xml 文件配置链接，并提示获取方式及上传方法
        yellow "获取 WARP Teams 账户 xml 配置文件方法：https://blog.misaka.rest/2023/02/11/wgcfteam-config/"
        yellow "请将提取到的 xml 配置文件上传至：https://gist.github.com"
        read -rp "请粘贴 WARP Teams 账户配置文件链接：" teamconfigurl
        if [[ -n $teamconfigurl ]]; then
            # 将一些字符过滤，以便脚本识别出内容
            teams_config=$(curl -sSL "$teamconfigurl" | sed "s/\"/\&quot;/g")

            # 获取私钥以及 IPv6 内网地址，用于替换 wgcf.conf 和 wgcf-profile.conf 文件中对应的内容
            private_key=$(expr "$teams_config" : '.*private_key&quot;>\([^<]*\).*')
            private_v6=$(expr "$teams_config" : '.*v6&quot;:&quot;\([^[&]*\).*')
            sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/proxy.conf;
            sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/wgcf-profile.conf;
            sed -i "s#Address.*128#Address = $private_v6/128#g" /etc/wireguard/wgcf-profile.conf;

            # 启动 WireProxy，并检查是否正常运行
            yellow "正在启动 WireProxy-WARP 代理模式"
            systemctl start wireproxy-warp
            wireproxy_status=$(curl -sx socks5h://localhost:$wireproxy_port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
            sleep 2
            retry_time=0
            until [[ $wireproxy_status =~ on|plus ]]; do
                retry_time=$((${retry_time} + 1))
                red "启动 WireProxy-WARP 代理模式失败，正在尝试重启，重试次数：$retry_time"
                systemctl stop wireproxy-warp
                systemctl start wireproxy-warp
                wireproxy_status=$(curl -sx socks5h://localhost:$port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
                if [[ $retry_time == 6 ]]; then
                    echo ""
                    red "安装 WireProxy-WARP 代理模式失败！"
                    green "建议如下："
                    yellow "1. 强烈建议使用官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为官方源"
                    yellow "2. 部分 VPS 系统极度精简，相关依赖需自行安装后再尝试"
                    yellow "3. 查看 https://www.cloudflarestatus.com/ ，你当前VPS就近区域可能处于黄色的【Re-routed】状态"
                    yellow "4. WGCF 在香港、美西区域遭到 CloudFlare 官方封禁"
                    yellow "5. 脚本可能跟不上时代, 建议截图发布到 GitLab Issues 或 TG 群询问"
                    exit 1
                fi
                sleep 8
            done
            sleep 5
            systemctl enable wireproxy-warp >/dev/null 2>&1
            green "WireProxy-WARP 代理模式已启动成功!"
            before_showinfo && show_info
        else
            red "未提供WARP Teams 账户配置文件链接，脚本退出！"
        fi
    else
        # 关闭 WireProxy
        systemctl stop wireproxy-warp
        systemctl disable wireproxy-warp

        # 删除原来的账号及 WireGuard 配置文件
        rm -f /etc/wireguard/wgcf-account.toml /etc/wireguard/wgcf-profile.conf

        # 在 WGCF 处注册账户
        register_wgcf

        # 移动新的账号及 WireGuard 配置文件
        mv -f wgcf-profile.conf /etc/wireguard/wgcf-profile.conf
        mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml

        # 获取私钥，用于替换 proxy.conf 文件中对应的内容
        private_key=$(grep PrivateKey /etc/wireguard/wgcf-profile.conf | sed "s/PrivateKey = //g")
        sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/proxy.conf;

        # 启动 WireProxy，并检查是否正常运行
        yellow "正在启动 WireProxy-WARP 代理模式"
        systemctl start wireproxy-warp
        wireproxy_status=$(curl -sx socks5h://localhost:$port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        sleep 2
        retry_time=0
        until [[ $wireproxy_status =~ on|plus ]]; do
            retry_time=$((${retry_time} + 1))
            red "启动 WireProxy-WARP 代理模式失败，正在尝试重启，重试次数：$retry_time"
            systemctl stop wireproxy-warp
            systemctl start wireproxy-warp
            wireproxy_status=$(curl -sx socks5h://localhost:$port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
            if [[ $retry_time == 6 ]]; then
                echo ""
                red "安装 WireProxy-WARP 代理模式失败！"
                green "建议如下："
                yellow "1. 强烈建议使用官方源升级系统及内核加速！如已使用第三方源及内核加速，请务必更新到最新版，或重置为官方源"
                yellow "2. 部分 VPS 系统极度精简，相关依赖需自行安装后再尝试"
                yellow "3. 查看 https://www.cloudflarestatus.com/ ，你当前VPS就近区域可能处于黄色的【Re-routed】状态"
                yellow "4. WGCF 在香港、美西区域遭到 CloudFlare 官方封禁"
                yellow "5. 脚本可能跟不上时代, 建议截图发布到 GitLab Issues 或 TG 群询问"
                exit 1
            fi
            sleep 8
        done
        sleep 5
        systemctl enable wireproxy-warp >/dev/null 2>&1
        green "WireProxy-WARP 代理模式已启动成功!"
        before_showinfo && show_info
    fi
}

warp_account() {
    yellow "请选择需要切换账户的 WARP 客户端"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} WGCF ${YELLOW}(默认)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} WARP-GO"
    echo -e " ${GREEN}3.${PLAIN} WARP-Cli ${RED}(仅支持升级至 WARP+)${PLAIN}"
    echo -e " ${GREEN}4.${PLAIN} WireProxy"
    echo ""
    read -p "请输入选项 [1-4]: " account_mode
    if [[ $account_mode == 2 ]]; then
        wpgo_account
    elif [[ $account_mode == 3 ]]; then
        warp_cli_account
    elif [[ $account_mode == 4 ]]; then
        wireproxy_account
    else
        wgcf_account
    fi
}

before_showinfo() {
    yellow "请等待，正在检测 VPS、WARP 以及解锁状态..."

    # 获取出站 IPv4 / IPv6 的地址、提供商
    check_ip
    country4=$(expr "$(curl -ks4m8 -A Mozilla https://api.ip.sb/geoip)" : '.*country\":[ ]*\"\([^"]*\).*')
    country6=$(expr "$(curl -ks6m8 -A Mozilla https://api.ip.sb/geoip)" : '.*country\":[ ]*\"\([^"]*\).*')
    provider4=$(expr "$(curl -ks4m8 -A Mozilla https://api.ip.sb/geoip)" : '.*isp\":[ ]*\"\([^"]*\).*')
    provider6=$(expr "$(curl -ks6m8 -A Mozilla https://api.ip.sb/geoip)" : '.*isp\":[ ]*\"\([^"]*\).*')

    # 获取出站 WARP 账户状态
    check_warp

    # 初始化 IPv4 / IPv6 设备名称，默认为未设置
    device4="${RED}未设置${PLAIN}"
    device6="${RED}未设置${PLAIN}"

    # 获取 WARP-Cli 和 WireProxy 的 socks5 端口
    cli_port=$(warp-cli --accept-tos settings 2>/dev/null | grep 'WarpProxy on port' | awk -F "port " '{print $2}')
    wireproxy_port=$(grep BindAddress /etc/wireguard/proxy.conf 2>/dev/null | sed "s/BindAddress = 127.0.0.1://g")

    # 如获取到 WARP-Cli 和 WireProxy 的 socks5 端口，则获取其的 IP 的地址、提供商、WARP状态信息
    if [[ -n $cli_port ]]; then
        account_cli=$(curl -sx socks5h://localhost:$cli_port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        country_cli=$(expr "$(curl -sx socks5h://localhost:$cli_port -A Mozilla https://api.ip.sb/geoip -k --connect-timeout 8)" : '.*country\":[ ]*\"\([^"]*\).*')
        ip_cli=$(expr "$(curl -sx socks5h://localhost:$cli_port -A Mozilla https://api.ip.sb/geoip -k --connect-timeout 8)" : '.*ip\":[ ]*\"\([^"]*\).*')
        provider_cli=$(expr "$(curl -sx socks5h://localhost:$cli_port -A Mozilla https://api.ip.sb/geoip -k --connect-timeout 8)" : '.*isp\":[ ]*\"\([^"]*\).*')
    fi
    if [[ -n $wireproxy_port ]]; then
        account_wireproxy=$(curl -sx socks5h://localhost:$wireproxy_port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        country_wireproxy=$(expr "$(curl -sx socks5h://localhost:$wireproxy_port -A Mozilla https://api.ip.sb/geoip -k --connect-timeout 8)" : '.*country\":[ ]*\"\([^"]*\).*')
        ip_wireproxy=$(expr "$(curl -sx socks5h://localhost:$wireproxy_port -A Mozilla https://api.ip.sb/geoip -k --connect-timeout 8)" : '.*ip\":[ ]*\"\([^"]*\).*')
        provider_wireproxy=$(expr "$(curl -sx socks5h://localhost:$wireproxy_port -A Mozilla https://api.ip.sb/geoip -k --connect-timeout 8)" : '.*isp\":[ ]*\"\([^"]*\).*')
    fi

    # 获取 WARP 账户状态、设备名称和剩余流量，并返回至用户回显
    if [[ $warp_v4 == "plus" ]]; then
        if [[ -n $(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }') ]]; then
            d4=$(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }')
            check_quota
            quota4="${GREEN} $QUOTA ${PLAIN}"
            account4="${GREEN}WARP+${PLAIN}"
        elif [[ $(grep -s "Type" /opt/warp-go/warp.conf | cut -d= -f2 | sed "s# ##g") == "plus" ]]; then
            check_quota
            quota4="${GREEN} $QUOTA ${PLAIN}"
            account4="${GREEN}WARP+${PLAIN}"
        else
            quota4="${RED}无限制${PLAIN}"
            account4="${GREEN}WARP Teams${PLAIN}"
        fi
    elif [[ $warp_v4 == "on" ]]; then
        quota4="${RED}无限制${PLAIN}"
        account4="${YELLOW}WARP 免费账户${PLAIN}"
    else
        quota4="${RED}无限制${PLAIN}"
        account4="${RED}未启用WARP${PLAIN}"
    fi

    if [[ $warp_v6 == "plus" ]]; then
        if [[ -n $(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }') ]]; then
            d6=$(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }')
            check_quota
            quota6="${GREEN} $QUOTA ${PLAIN}"
            account6="${GREEN}WARP+${PLAIN}"
        elif [[ $(grep -s "Type" /opt/warp-go/warp.conf | cut -d= -f2 | sed "s# ##g") == "plus" ]]; then
            check_quota
            quota6="${GREEN} $QUOTA ${PLAIN}"
            account6="${GREEN}WARP+${PLAIN}"
        else
            quota6="${RED}无限制${PLAIN}"
            account6="${GREEN}WARP Teams${PLAIN}"
        fi
    elif [[ $warp_v6 == "on" ]]; then
        quota6="${RED}无限制${PLAIN}"
        account6="${YELLOW}WARP 免费账户${PLAIN}"
    else
        quota6="${RED}无限制${PLAIN}"
        account6="${RED}未启用WARP${PLAIN}"
    fi

    if [[ $account_cli == "plus" ]]; then
        CHECK_TYPE=1
        check_quota
        quota_cli="${GREEN} $QUOTA ${PLAIN}"
        account_cli="${GREEN}WARP+${PLAIN}"
    elif [[ $account_cli == "on" ]]; then
        quota_cli="${RED}无限制${PLAIN}"
        account_cli="${YELLOW}WARP 免费账户${PLAIN}"
    else
        quota_cli="${RED}无限制${PLAIN}"
        account_cli="${RED}未启动${PLAIN}"
    fi

    if [[ $account_wireproxy == "plus" ]]; then
        if [[ -n $(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }') ]]; then
            device_wireproxy=$(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }')
            check_quota
            quota_wireproxy="${GREEN} $QUOTA ${PLAIN}"
            account_wireproxy="${GREEN}WARP+${PLAIN}"
        else
            quota_wireproxy="${RED}无限制${PLAIN}"
            account_wireproxy="${GREEN}WARP Teams${PLAIN}"
        fi
    elif [[ $account_wireproxy == "on" ]]; then
        quota_wireproxy="${RED}无限制${PLAIN}"
        account_wireproxy="${YELLOW}WARP 免费账户${PLAIN}"
    else
        quota_wireproxy="${RED}无限制${PLAIN}"
        account_wireproxy="${RED}未启动${PLAIN}"
    fi

    # 检测本地是否安装了 Netflix 检测脚本，如未安装则下载并安装检测脚本，感谢：https://github.com/sjlleo/netflix-verify
    if [[ ! -f /usr/local/bin/nf ]]; then
        wget https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/netflix-verify/nf-linux-$(archAffix) -O /usr/local/bin/nf >/dev/null 2>&1
        chmod +x /usr/local/bin/nf
    fi

    # 测试 Netflix 解锁情况
    netflix4=$(nf | sed -n 3p | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")
    netflix6=$(nf | sed -n 7p | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g") && [[ -n $(echo $netflix6 | grep "NF所识别的IP地域信息") ]] && netflix6=$(nf | sed -n 6p | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")
    [[ -n $cli_port ]] && netflix_cli=$(nf -proxy socks5://127.0.0.1:$cli_port | sed -n 3p | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")
    [[ -n $wireproxy_port ]] && netflix_wireproxy=$(nf -proxy socks5://127.0.0.1:$wireproxy_port | sed -n 3p | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")

    # 简化 Netflix 检测脚本输出结果，以便输出结果的排版
    [[ $netflix4 == "您的出口IP完整解锁Netflix，支持非自制剧的观看" ]] && netflix4="${GREEN}已解锁 Netflix${PLAIN}"
    [[ $netflix6 == "您的出口IP完整解锁Netflix，支持非自制剧的观看" ]] && netflix6="${GREEN}已解锁 Netflix${PLAIN}"
    [[ $netflix4 == "您的出口IP可以使用Netflix，但仅可看Netflix自制剧" ]] && netflix4="${YELLOW}Netflix 自制剧${PLAIN}"
    [[ $netflix6 == "您的出口IP可以使用Netflix，但仅可看Netflix自制剧" ]] && netflix6="${YELLOW}Netflix 自制剧${PLAIN}"
    [[ -z $netflix4 ]] || [[ $netflix4 == "您的网络可能没有正常配置IPv4，或者没有IPv4网络接入" ]] && netflix4="${RED}无法检测 Netflix 状态${PLAIN}"
    [[ -z $netflix6 ]] || [[ $netflix6 == "您的网络可能没有正常配置IPv6，或者没有IPv6网络接入" ]] && netflix6="${RED}无法检测 Netflix 状态${PLAIN}"
    [[ $netflix4 =~ "Netflix在您的出口IP所在的国家不提供服务"|"Netflix在您的出口IP所在的国家提供服务，但是您的IP疑似代理，无法正常使用服务" ]] && netflix4="${RED}无法解锁 Netflix${PLAIN}"
    [[ $netflix6 =~ "Netflix在您的出口IP所在的国家不提供服务"|"Netflix在您的出口IP所在的国家提供服务，但是您的IP疑似代理，无法正常使用服务" ]] && netflix6="${RED}无法解锁 Netflix${PLAIN}"
    [[ $netflix_cli == "您的出口IP完整解锁Netflix，支持非自制剧的观看" ]] && netflix_cli="${GREEN}已解锁 Netflix${PLAIN}"
    [[ $netflix_wireproxy == "您的出口IP完整解锁Netflix，支持非自制剧的观看" ]] && netflix_wireproxy="${GREEN}已解锁 Netflix${PLAIN}"
    [[ $netflix_cli == "您的出口IP可以使用Netflix，但仅可看Netflix自制剧" ]] && netflix_cli="${YELLOW}Netflix 自制剧${PLAIN}"
    [[ $netflix_wireproxy == "您的出口IP可以使用Netflix，但仅可看Netflix自制剧" ]] && netflix_wireproxy="${YELLOW}Netflix 自制剧${PLAIN}"
    [[ $netflix_cli =~ "Netflix在您的出口IP所在的国家不提供服务"|"Netflix在您的出口IP所在的国家提供服务，但是您的IP疑似代理，无法正常使用服务" ]]&& netflix_cli="${RED}无法解锁 Netflix${PLAIN}"
    [[ $netflix_wireproxy =~ "Netflix在您的出口IP所在的国家不提供服务"|"Netflix在您的出口IP所在的国家提供服务，但是您的IP疑似代理，无法正常使用服务" ]]&& netflix_wireproxy="${RED}无法解锁 Netflix${PLAIN}"

    # 测试 ChatGPT 解锁情况
    curl -s4m8 https://chat.openai.com/ | grep -qw "Sorry, you have been blocked" && chatgpt4="${RED}无法访问 ChatGPT${PLAIN}" || chatgpt4="${GREEN}支持访问 ChatGPT${PLAIN}"
    curl -s6m8 https://chat.openai.com/ | grep -qw "Sorry, you have been blocked" && chatgpt6="${RED}无法访问 ChatGPT${PLAIN}" || chatgpt6="${GREEN}支持访问 ChatGPT${PLAIN}"
    if [[ -n $cli_port ]]; then
        curl -sx socks5h://localhost:$cli_port https://chat.openai.com/ | grep -qw "Sorry, you have been blocked" && chatgpt_cli="${RED}无法访问 ChatGPT${PLAIN}" || chatgpt_cli="${GREEN}支持访问 ChatGPT${PLAIN}"
    fi
    if [[ -n $wireproxy_port ]]; then
        curl -sx socks5h://localhost:$wireproxy_port https://chat.openai.com/ | grep -qw "Sorry, you have been blocked" && chatgpt_wireproxy="${RED}无法访问 ChatGPT${PLAIN}" || chatgpt_wireproxy="${GREEN}支持访问 ChatGPT${PLAIN}"
    fi
}

show_info() {
    echo "----------------------------------------------------------------------------"
    if [[ -n $ipv4 ]]; then
        echo -e "IPv4 地址：$ipv4  地区：$country4  设备名称：$device4"
        echo -e "提供商：$provider4  WARP 账户状态：$account4  剩余流量：$quota4"
        echo -e "Netflix 状态：$netflix4  ChatGPT 状态：$chatgpt4"
    else
        echo -e "IPv4 出站状态：${RED}未启用${PLAIN}"
    fi
    echo "----------------------------------------------------------------------------"
    if [[ -n $ipv6 ]]; then
        echo -e "IPv6 地址：$ipv6  地区：$country6  设备名称：$device6"
        echo -e "提供商：$provider6  WARP 账户状态：$account6  剩余流量：$quota6"
        echo -e "Netflix 状态：$netflix6  ChatGPT 状态：$chatgpt6"
    else
        echo -e "IPv6 出站状态：${RED}未启用${PLAIN}"
    fi
    echo "----------------------------------------------------------------------------"
    if [[ -n $cli_port ]]; then
        echo -e "WARP-Cli代理端口: 127.0.0.1:$cli_port  状态: $account_cli  剩余流量：$quota_cli"
        if [[ -n $ip_cli ]]; then
            echo -e "IP: $ip_cli  地区: $country_cli  提供商：$provider_cli"
            echo -e "Netflix 状态：$netflix_cli  ChatGPT 状态：$chatgpt_cli"
        fi
    else
        echo -e "WARP-Cli 出站状态：${RED}未安装${PLAIN}"
    fi
    echo "----------------------------------------------------------------------------"
    if [[ -n $wireproxy_port ]]; then
        echo -e "WireProxy-WARP代理端口: 127.0.0.1:$wireproxy_port  状态: $account_wireproxy  剩余流量：$quota_wireproxy"
        if [[ -n $ip_wireproxy ]]; then
            echo -e "IP: $ip_wireproxy  地区: $country_wireproxy  提供商：$provider_wireproxy"
            echo -e "Netflix 状态：$netflix_wireproxy  ChatGPT 状态：$chatgpt_wireproxy"
        fi
    else
        echo -e "WireProxy 出站状态：${RED}未安装${PLAIN}"
    fi
    echo "----------------------------------------------------------------------------"
}

menu() {
    clear
    echo "#############################################################"
    echo -e "#                ${RED}CloudFlare WARP 一键管理脚本${PLAIN}               #"
    echo -e "# ${GREEN}作者${PLAIN}: MisakaNo の 小破站                                  #"
    echo -e "# ${GREEN}博客${PLAIN}: https://blog.misaka.rest                            #"
    echo -e "# ${GREEN}GitHub 项目${PLAIN}: https://github.com/Misaka-blog               #"
    echo -e "# ${GREEN}GitLab 项目${PLAIN}: https://gitlab.com/Misaka-blog               #"
    echo -e "# ${GREEN}Telegram 频道${PLAIN}: https://t.me/misakanocchannel              #"
    echo -e "# ${GREEN}Telegram 群组${PLAIN}: https://t.me/misakanoc                     #"
    echo -e "# ${GREEN}YouTube 频道${PLAIN}: https://www.youtube.com/@misaka-blog        #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 / 切换 WGCF-WARP          | ${GREEN}3.${PLAIN} 安装 / 切换 WARP-GO"
    echo -e " ${GREEN}2.${PLAIN} ${RED}卸载 WGCF-WARP${PLAIN}                 | ${GREEN}4.${PLAIN} ${RED}卸载 WARP-GO${PLAIN}"
    echo " -------------------------------------------------------------"
    echo -e " ${GREEN}5.${PLAIN} 安装 WARP-Cli                  | ${GREEN}7.${PLAIN} 安装 WireProxy-WARP"
    echo -e " ${GREEN}6.${PLAIN} ${RED}卸载 WARP-Cli${PLAIN}                  | ${GREEN}8.${PLAIN} ${RED}卸载 WireProxy-WARP${PLAIN}"
    echo " -------------------------------------------------------------"
    echo -e " ${GREEN}9.${PLAIN} 修改 WARP-Cli / WireProxy 端口 | ${GREEN}10.${PLAIN} 开启、关闭或重启 WARP"
    echo -e " ${GREEN}11.${PLAIN} 提取 WireGuard 配置文件       | ${GREEN}12.${PLAIN} WARP+ 账户刷流量"
    echo -e " ${GREEN}13.${PLAIN} 切换 WARP 账户类型            | ${GREEN}14.${PLAIN} 从 GitLab 拉取最新脚本"
    echo " -------------------------------------------------------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    show_info
    echo ""
    read -rp "请输入选项 [0-14]: " menu_input
    case $menu_input in
        1) select_wgcf ;;
        2) uninstall_wgcf ;;
        3) select_wpgo ;;
        4) uninstall_wpgo ;;
        5) install_warp_cli ;;
        6) uninstall_warp_cli ;;
        7) install_wireproxy ;;
        8) uninstall_wireproxy ;;
        9) change_warp_port ;;
        10) switch_warp ;;
        11) wireguard_profile ;;
        12) warp_traffic ;;
        13) warp_account ;;
        14) wget -N https://gitlab.com/Misaka-blog/warp-script/-/raw/main/warp.sh && bash warp.sh ;;
        *) exit 1 ;;
    esac
}

before_showinfo && menu