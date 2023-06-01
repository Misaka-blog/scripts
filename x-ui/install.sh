#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

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

archAffix() {
    case "$(uname -m)" in
        x86_64 | amd64) echo 'amd64' ;;
        armv8 | arm64 | aarch64) echo 'arm64' ;;
        s390x) echo 's390x' ;;
        *) red "不支持的CPU架构!" && exit 1 ;;
    esac
}

install_base() {
    if [[ x"${RELEASE[int]}" == x"CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} install wget curl tar
    else
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} wget curl tar
    fi
}

# This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${YELLOW}For security reasons, you need to force a port and account password change after the installation/update is complete ${PLAIN}"
    read -p "Confirmation to continue? [y/n]: " config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Please set your account name (8 random characters if not filled in): " config_account
        [[ -z $config_account ]] && config_account=$(date +%s%N | md5sum | cut -c 1-8)
        echo -e "${YELLOW} your account name will be set to: ${config_account}${PLAIN}"
        read -p "Please set your account password (8 random characters if not filled in): " config_password
        [[ -z $config_password ]] && config_password=$(date +%s%N | md5sum | cut -c 1-8)
        echo -e "${YELLOW} your account password will be set to:${config_password}${PLAIN}"
        read -p "Please set the panel access port (or random port number if not filled in): " config_port
        [[ -z $config_port ]] && config_port=$(shuf -i 2000-65535 -n 1)
        until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; do
            if [[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; then
                echo -e "${RED} $config_port ${PLAIN} The port is already occupied by another program, please change the panel port number"
                read -p "Please set the panel access port (or random port number if not filled in): " config_port
                [[ -z $config_port ]] && config_port=$(shuf -i 2000-65535 -n 1)
            fi
        done
        echo -e "${YELLOW} your panel access port will be set to:${config_port}${PLAIN}"
        echo -e "${YELLOW}Confirm setting, setting in ${PLAIN}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${YELLOW} account password setting complete ${PLAIN}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${YELLOW} panel port setting complete ${PLAIN}"
    else
        config_port=$(/usr/local/x-ui/x-ui setting -show | sed -n 4p | awk -F ": " '{print $2}')
        echo -e "${RED}Account setting got cancelled, all settings are default, please change it as soon as possible!${PLAIN}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/sing-web/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${RED}Failed to detect x-ui version, may be out of Github API limit, please try again later, or manually specify x-ui version to install${PLAIN}"
            exit 1
        fi
        echo -e "The latest version of x-ui is detected: ${last_version}, start installation"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(archAffix).tar.gz https://github.com/sing-web/x-ui/releases/download/${last_version}/x-ui-linux-$(archAffix).tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}Downloading x-ui failed, please make sure your server can download the Github file${PLAIN}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/sing-web/x-ui/releases/download/${last_version}/x-ui-linux-$(archAffix).tar.gz"
        echo -e "Start installing x-ui $1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(archAffix).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}Downloading x-ui v$1 failed, please make sure this version exists${PLAIN}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-$(archAffix).tar.gz
    rm x-ui-linux-$(archAffix).tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-$(archAffix)
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/sing-web/x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "如果是全新安装，默认网页端口为 ${GREEN}54321${PLAIN}，用户名和密码默认都是 ${GREEN}admin${PLAIN}"
    #echo -e "请自行确保此端口没有被其他程序占用，${YELLOW}并且确保 54321 端口已放行${PLAIN}"
    #    echo -e "若想将 54321 修改为其它端口，输入 x-ui 命令进行修改，同样也要确保你修改的端口也是放行的"
    #echo -e ""
    #echo -e "如果是更新面板，则按你之前的方式访问面板"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    
    systemctl stop warp-go >/dev/null 2>&1
    wg-quick down wgcf >/dev/null 2>&1
    ipv4=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p)
    ipv6=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)
    systemctl start warp-go >/dev/null 2>&1
    wg-quick up wgcf >/dev/null 2>&1
    echo -e "${GREEN}x-ui ${last_version}${PLAIN} Installation completed, panel started"
    echo -e ""
    echo -e "How to use the x-ui administration script: "
    echo -e "----------------------------------------------"
    echo -e "x-ui - Show admin menu (more features)"
    echo -e "x-ui start - Start x-ui panel"
    echo -e "x-ui stop - stop the x-ui panel"
    echo -e "x-ui restart - restart the x-ui panel"
    echo -e "x-ui status - check x-ui status"
    echo -e "x-ui enable - set x-ui to start on its own"
    echo -e "x-ui disable - disable x-ui boot-up"
    echo -e "x-ui log - View x-ui logs"
    echo -e "x-ui update - Update the x-ui panel"
    echo -e "x-ui install - Install the x-ui panel"
    echo -e "x-ui uninstall - uninstall the x-ui panel"
    echo -e "----------------------------------------------"
    echo ""
    if [[ -n $ipv4 ]]; then
        echo -e "${YELLOW}The panel IPv4 access address is:${PLAIN} ${GREEN}http://$ipv4:$config_port ${PLAIN}"
    fi
    if [[ -n $ipv6 ]]; then
        echo -e "${YELLOW}The panel IPv6 access address is:${PLAIN} ${GREEN}http://[$ipv6]:$config_port ${PLAIN}"
    fi
    echo -e "Please make sure that this port is not occupied by another application, ${YELLOW} and that the ${PLAIN} ${RED} $config_port ${PLAIN} ${YELLOW} port is released ${PLAIN}"
}

echo -e "${GREEN}Begin installation${PLAIN}"
install_base
install_x-ui $1