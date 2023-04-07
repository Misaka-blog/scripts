#!/bin/bash

export LANG=en_US.UTF-8

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

# 判断系统及定义系统安装依赖方式
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove")

[[ $EUID -ne 0 ]] && red "注意: 请在root用户下运行脚本" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "目前暂不支持你的VPS的操作系统！" && exit 1

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
        * ) red "不支持的CPU架构!" && exit 1 ;;
    esac
}

realip(){
    ip=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p) || ip=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)
}

insttuic(){
    warpv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    warpv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ $warpv4 =~ on|plus || $warpv6 =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        systemctl stop warp-go >/dev/null 2>&1
        realip
        systemctl start warp-go >/dev/null 2>&1
        wg-quick up wgcf >/dev/null 2>&1
    else
        realip
    fi

    if [[ ! ${SYSTEM} == "CentOS" ]]; then
        ${PACKAGE_UPDATE}
    fi
    ${PACKAGE_INSTALL} wget curl sudo

    wget https://gitlab.com/Misaka-blog/tuic-script/-/raw/main/files/tuic-latest-linux-$(archAffix) -O /usr/local/bin/tuic
    if [[ -f "/usr/local/bin/tuic" ]]; then
        chmod +x /usr/local/bin/tuic
    else
        red "Tuic 内核安装失败！"
        exit 1
    fi
    
    green "Tuic 协议证书申请方式如下："
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 脚本自动申请 ${YELLOW}（默认）${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} 自定义证书路径"
    echo ""
    read -rp "请输入选项 [1-2]: " certInput
    if [[ $certInput == 2 ]]; then
        read -p "请输入公钥文件crt的路径：" certpath
        yellow "公钥文件crt的路径：$certpath "
        read -p "请输入密钥文件key的路径：" keypath
        yellow "密钥文件key的路径：$keypath "
        read -p "请输入证书的域名：" domain
        yellow "证书域名：$domain"
    else
        certpath="/root/cert.crt"
        keypath="/root/private.key"
        if [[ -f /root/cert.crt && -f /root/private.key ]] && [[ -s /root/cert.crt && -s /root/private.key ]] && [[ -f /root/ca.log ]]; then
            domain=$(cat /root/ca.log)
            green "检测到原有域名：$domain 的证书，正在应用"
        else
            read -p "请输入需要申请证书的域名：" domain
            [[ -z $domain ]] && red "未输入域名，无法执行操作！" && exit 1
            green "已输入的域名：$domain" && sleep 1
            domainIP=$(curl -sm8 ipget.net/?ip="${domain}")
            if [[ $domainIP == $ip ]]; then
                if [[ -n $(echo $ip | grep ":") ]]; then
                    bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --listen-v6 --insecure
                else
                    bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --insecure
                fi
                bash ~/.acme.sh/acme.sh --install-cert -d ${domain} --key-file /root/private.key --fullchain-file /root/cert.crt --ecc
                if [[ -f /root/cert.crt && -f /root/private.key ]] && [[ -s /root/cert.crt && -s /root/private.key ]]; then
                    echo $domain > /root/ca.log
                    sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
                    echo "0 0 * * * root bash /root/.acme.sh/acme.sh --cron -f >/dev/null 2>&1" >> /etc/crontab
                    green "证书申请成功! 脚本申请到的证书 (cert.crt) 和私钥 (private.key) 文件已保存到 /root 文件夹下"
                    yellow "证书crt文件路径如下: /root/cert.crt"
                    yellow "私钥key文件路径如下: /root/private.key"
                fi
            else
                red "当前域名解析的IP与当前VPS使用的真实IP不匹配"
                green "建议如下："
                yellow "1. 请确保CloudFlare小云朵为关闭状态(仅限DNS), 其他域名解析或CDN网站设置同理"
                yellow "2. 请检查DNS解析设置的IP是否为VPS的真实IP"
                yellow "3. 脚本可能跟不上时代, 建议截图发布到GitHub Issues、GitLab Issues、论坛或TG群询问"
            fi
        fi
    fi

    read -p "设置 tuic 端口[1-65535]（回车则随机分配端口）：" port
    [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
    until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; do
        if [[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; then
            echo -e "${RED} $port ${PLAIN} 端口已经被其他程序占用，请更换端口重试！"
            read -p "设置 tuic 端口[1-65535]（回车则随机分配端口）：" port
            [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
        fi
    done

    read -p "设置tuic Token（回车跳过为随机字符）：" token
    [[ -z $token ]] && token=$(date +%s%N | md5sum | cut -c 1-8)

    green "正在配置 Tuic..."
    mkdir /etc/tuic >/dev/null 2>&1
    cat <<EOF > /etc/tuic/tuic.json
{
    "port": $port,
    "token": ["$token"],
    "certificate": "$certpath",
    "private_key": "$keypath",
    "ip": "::",
    "congestion_controller": "bbr",
    "alpn": ["h3"]
}
EOF
    mkdir /root/tuic >/dev/null 2>&1
    cat <<EOF > /root/tuic/v2rayn.json
{
    "relay": {
        "server": "$domain",
        "port": $port,
        "token": "$token",
        "ip": "$ip",
        "congestion_controller": "bbr",
        "udp_relay_mode": "quic",
        "alpn": ["h3"],
        "disable_sni": false,
        "reduce_rtt": false,
        "max_udp_relay_packet_size": 1500
    },
    "local": {
        "port": 6080,
        "ip": "127.0.0.1"
    },
    "log_level": "off"
}
EOF

    cat <<EOF > /root/tuic/tuic.txt
Sagernet 与 小火箭 配置说明（以下6项必填）：
{
    服务器地址：$domain
    服务器端口：$port
    token：$token
    ALPN：h3
    UDP转发：开启
    congestion controller：bbr
}
EOF

    cat << EOF >/etc/systemd/system/tuic.service
[Unit]
Description=tuic Service
Documentation=https://gitlab.com/Misaka-blog/tuic-script
After=network.target
[Service]
User=root
ExecStart=/usr/local/bin/tuic -c /etc/tuic/tuic.json
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable tuic
    systemctl start tuic
    if [[ -n $(systemctl status tuic 2>/dev/null | grep -w active) && -f '/etc/tuic/tuic.json' ]]; then
        green "tuic 服务启动成功"
    else
        red "tuic 服务启动失败，请运行systemctl status tuic查看服务状态并反馈，脚本退出" && exit 1
    fi
    red "======================================================================================"
    url="tuic://$domain:$port?password=$token&alpn=h3&mode=bbr#tuic-misaka"
    echo ${url} > /root/tuic/URL.txt
    green "Tuic 代理服务安装完成"
    yellow "v2rayn 客户端配置文件 v2rayn.json 内容如下，并保存到 /root/tuic/v2rayn.json"
    cat /root/tuic/v2rayn.json
    yellow "Tuic 节点配置明文如下，并保存到 /root/tuic/tuic.txt"
    cat /root/tuic/tuic.txt
}

unsttuic(){
    systemctl stop tuic
    systemctl disable tuic
    rm -f /etc/systemd/system/tuic.service /root/tuic.sh
    rm -rf /usr/local/bin/tuic /etc/tuic /root/tuic
    green "Tuic 已彻底卸载完成！"
}

starttuic(){
    systemctl start tuic
    systemctl enable tuic >/dev/null 2>&1
}

stoptuic(){
    systemctl stop tuic
    systemctl disable tuic >/dev/null 2>&1
}

tuicswitch(){
    yellow "请选择你需要的操作："
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 启动 Tuic"
    echo -e " ${GREEN}2.${PLAIN} 关闭 Tuic"
    echo -e " ${GREEN}3.${PLAIN} 重启 Tuic"
    echo ""
    read -rp "请输入选项 [0-3]: " switchInput
    case $switchInput in
        1 ) starttuic ;;
        2 ) stoptuic ;;
        3 ) stoptuic && starttuic ;;
        * ) exit 1 ;;
    esac
}

changeport(){
    oldport=$(cat /etc/tuic/tuic.json 2>/dev/null | sed -n 2p | awk '{print $2}'| tr -d ',')
    read -p "设置 tuic 端口[1-65535]（回车则随机分配端口）：" port
    [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)

    until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; do
        if [[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; then
            echo -e "${RED} $port ${PLAIN} 端口已经被其他程序占用，请更换端口重试！"
            read -p "设置 tuic 端口[1-65535]（回车则随机分配端口）：" port
            [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
        fi
    done

    sed -i "2s/$oldport/$port/g" /etc/tuic/tuic.json
    sed -i "4s/$oldport/$port/g" /root/tuic/v2rayn.json
    sed -i "4s/$oldport/$port/g" /root/tuic/tuic.txt
    stoptuic && starttuic
}

changetoken(){
    oldtoken=$(cat /etc/tuic/tuic.json 2>/dev/null | sed -n 3p | awk '{print $2}' | tr -d ',[]"')
    read -p "设置tuic Token（回车跳过为随机字符）：" token
    [[ -z $token ]] && token=$(date +%s%N | md5sum | cut -c 1-8)

    sed -i "3s/$oldtoken/$token/g" /etc/tuic/tuic.json
    sed -i "5s/$oldtoken/$token/g" /root/tuic/v2rayn.json
    sed -i "5s/$oldtoken/$token/g" /root/tuic/tuic.txt
    stoptuic && starttuic
}

changeconf(){
    green "Tuic 配置变更选择如下:"
    echo -e " ${GREEN}1.${PLAIN} 修改端口"
    echo -e " ${GREEN}2.${PLAIN} 修改Token"
    echo ""
    read -p " 请选择操作[1-2]：" confAnswer
    case $confAnswer in
        1 ) changeport ;;
        2 ) changetoken ;;
        * ) exit 1 ;;
    esac
}

showconf(){
    yellow "v2rayn客户端配置文件v2rayn.json内容如下，并保存到 /root/tuic/v2rayn.json"
    cat /root/tuic/v2rayn.json
    yellow "Tuic节点配置明文如下，并保存到 /root/tuic/tuic.txt"
    cat /root/tuic/tuic.txt
}

menu() {
    clear
    echo "#############################################################"
    echo -e "#                   ${RED}Tuic 一键安装脚本${PLAIN}                      #"
    echo -e "# ${GREEN}作者${PLAIN}: MisakaNo の 小破站                                  #"
    echo -e "# ${GREEN}博客${PLAIN}: https://blog.misaka.rest                            #"
    echo -e "# ${GREEN}GitHub 项目${PLAIN}: https://github.com/Misaka-blog               #"
    echo -e "# ${GREEN}GitLab 项目${PLAIN}: https://gitlab.com/Misaka-blog               #"
    echo -e "# ${GREEN}Telegram 频道${PLAIN}: https://t.me/misakablogchannel             #"
    echo -e "# ${GREEN}Telegram 群组${PLAIN}: https://t.me/misakanoxpz                   #"
    echo -e "# ${GREEN}YouTube 频道${PLAIN}: https://www.youtube.com/@misaka-blog        #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 Tuic"
    echo -e " ${GREEN}2.${PLAIN} ${RED}卸载 Tuic${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}3.${PLAIN} 关闭、开启、重启 Tuic"
    echo -e " ${GREEN}4.${PLAIN} 修改 Tuic 配置"
    echo -e " ${GREEN}5.${PLAIN} 显示 Tuic 配置文件"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    read -rp "请输入选项 [0-5]: " menuInput
    case $menuInput in
        1 ) insttuic ;;
        2 ) unsttuic ;;
        3 ) tuicswitch ;;
        4 ) changeconf ;;
        5 ) showconf ;;
        * ) exit 1 ;;
    esac
}

menu