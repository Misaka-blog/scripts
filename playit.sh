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

archAffix(){
    case "$(uname -m)" in
        x86_64 | amd64 ) echo 'amd64' ;;
        armv8 | arm64 | aarch64 ) echo 'aarch64' ;;
        * ) red "不支持的CPU架构!" && exit 1 ;;
    esac
}

instplayit(){
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} curl wget sudo

    if [[ $(archAffix) == "amd64"]]; then
        wget -O /usr/local/bin/playit https://github.com/playit-cloud/playit-agent/releases/download/v0.9.3/playit-0.9.3
    else
        wget -O /usr/local/bin/playit https://github.com/playit-cloud/playit-agent/releases/download/v0.9.3/playit-0.9.3-aarch64
    fi

    if [[ -f "/usr/local/bin/playit" ]]; then
        chmod +x /usr/local/bin/playit
        green "Playit 隧道程序下载成功，当前版本为 $(playit -V)"
    else
        red "下载 Playit 文件失败，请检查本机网络是否链接上GitHub！"
    fi

    yellow "请复制接下来的链接至浏览器，以进行Playit账户登录。登录完成之后按下Ctrl+C退出程序"
    read -p "按下回车键以继续"

    playit

    clear
    if [[ -f "./playit.toml" ]]; then
        green "Playit 账户登录成功，正在安装系统守护"
    else
        red "Playit 账户登录失败，请卸载后重试！"
        exit 1
    fi
    
    mkdir /etc/playit >/dev/null 2>&1
    mv playit.toml /etc/playit/playit.toml
    cat << EOF >/etc/systemd/system/playit.service
[Unit]
Description=Playit Tunnel Service
Documentation=https://github.com/Misaka-blog/playit-tunnel
After=network.target
[Service]
User=root
ExecStart=/usr/local/bin/playit -c /etc/playit/playit.toml
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF
    if [[ -n $(systemctl status playit 2>/dev/null | grep -w active) && -f '/etc/playit/playit.toml' ]]; then
        green "Playit 隧道程序启动成功"
        yellow "请继续在网页：https://playit.gg/account/overview 设置隧道详细参数"
    else
        red "Playit 隧道程序启动失败，请运行systemctl status playit查看服务状态并反馈，脚本退出"
        exit 1
    fi
}

unstplayit(){
    systemctl stop playit
    systemctl disable playit
    rm -f /etc/systemd/system/playit.service /root/playit.sh
    rm -rf /usr/local/bin/playit /etc/playit
    green "Playit 隧道程序已彻底卸载完成！"
}

unstplayit(){
    systemctl stop playit
    systemctl disable playit
    rm -f /etc/systemd/system/playit.service /root/playit.sh
    rm -rf /usr/local/bin/playit /etc/playit /root/playit
    green "playit 已彻底卸载完成！"
}

startplayit(){
    systemctl start playit
    systemctl enable playit >/dev/null 2>&1
}

stopplayit(){
    systemctl stop playit
    systemctl disable playit >/dev/null 2>&1
}

playitswitch(){
    echo ""
    yellow "请选择你需要的操作："
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 启动 Playit"
    echo -e " ${GREEN}2.${PLAIN} 关闭 Playit"
    echo -e " ${GREEN}3.${PLAIN} 重启 Playit"
    echo ""
    read -rp "请输入选项 [0-3]: " switchInput
    case $switchInput in
        1 ) startplayit ;;
        2 ) stopplayit ;;
        3 ) stopplayit && startplayit ;;
        * ) exit 1 ;;
    esac
}

menu() {
    clear
    echo "#############################################################"
    echo -e "#                  ${RED}Playit 隧道一键脚本${PLAIN}                     #"
    echo -e "# ${GREEN}作者${PLAIN}: MisakaNo の 小破站                                  #"
    echo -e "# ${GREEN}博客${PLAIN}: https://blog.misaka.rest                            #"
    echo -e "# ${GREEN}GitHub 项目${PLAIN}: https://github.com/Misaka-blog               #"
    echo -e "# ${GREEN}Telegram 频道${PLAIN}: https://t.me/misakablogchannel             #"
    echo -e "# ${GREEN}Telegram 群组${PLAIN}: https://t.me/misakanoxpz                   #"
    echo -e "# ${GREEN}YouTube 频道${PLAIN}: https://www.youtube.com/@misaka-blog        #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 Playit 隧道程序"
    echo -e " ${GREEN}2.${PLAIN} ${RED}卸载 Playit 隧道程序${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}3.${PLAIN} 关闭、开启、重启 Playit"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    read -rp "请输入选项 [0-2]: " menuInput
    case $menuInput in
        1 ) instplayit ;;
        2 ) unstplayit ;;
        3 ) playitswitch ;;
        * ) exit 1 ;;
    esac
}

menu