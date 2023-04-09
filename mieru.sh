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
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        * ) red "不支持的CPU架构!" && exit 1 ;;
    esac
}

inst_mita(){
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL} curl wget sudo

    last_version=$(curl -s https://data.jsdelivr.com/v1/package/gh/enfein/mieru | sed -n 4p | tr -d ',"' | awk '{print $1}')
    if [[ $SYSTEM == "CentOS" ]]; then
        [[ $(archAffix) == "amd64" ]] && arch="x86_64" || [[ $(archAffix) == "arm64" ]] && arch="aarch64"
        wget -N https://github.com/enfein/mieru/releases/download/v"$last_version"/mita-"$last_version"-1."$arch".rpm
        rpm -ivh mita-$last_version-1.$arch.rpm
        rm -f mita-$last_version-1.$arch.rpm
    else
        wget -N https://github.com/enfein/mieru/releases/download/v"$last_version"/mita_"$last_version"_$(archAffix).deb
        dpkg -i mita_"$last_version"_$(archAffix).deb
        rm -f mita_"$last_version"_$(archAffix).deb
    fi

    cat <<EOF > server_config.json
{
    "portBindings": [
        {
            "port": 22345,
            "protocol": "TCP"
        }
    ],
    "users": [
        {
            "name": "pingzi",
            "password": "solo220poundMaiZi"
        }
    ],
    "loggingLevel": "INFO",
    "mtu": 1400
}
EOF

    mita apply config server_config.json

    mita start
    mita status
}

menu() {
    clear
    echo "#############################################################"
    echo -e "#                   ${RED}mieru 一键安装脚本${PLAIN}                      #"
    echo -e "# ${GREEN}作者${PLAIN}: MisakaNo の 小破站                                  #"
    echo -e "# ${GREEN}博客${PLAIN}: https://blog.misaka.rest                            #"
    echo -e "# ${GREEN}GitHub 项目${PLAIN}: https://github.com/Misaka-blog               #"
    echo -e "# ${GREEN}GitLab 项目${PLAIN}: https://gitlab.com/Misaka-blog               #"
    echo -e "# ${GREEN}Telegram 频道${PLAIN}: https://t.me/misakanocchannel              #"
    echo -e "# ${GREEN}Telegram 群组${PLAIN}: https://t.me/misakanoc                     #"
    echo -e "# ${GREEN}YouTube 频道${PLAIN}: https://www.youtube.com/@misaka-blog        #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 mieru"
    echo -e " ${GREEN}2.${PLAIN} ${RED}卸载 mieru${PLAIN}"
    echo " -------------"
    echo -e " ${GREEN}3.${PLAIN} 关闭、开启、重启 mieru"
    echo -e " ${GREEN}4.${PLAIN} 修改 mieru 配置"
    echo -e " ${GREEN}5.${PLAIN} 显示 mieru 配置文件"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    read -rp "请输入选项 [0-5]: " menuInput
    case $menuInput in
        1 ) inst_mita ;;
        2 ) unst_mita ;;
        3 ) mita_switch ;;
        4 ) edit_conf ;;
        5 ) show_conf ;;
        * ) exit 1 ;;
    esac
}

menu