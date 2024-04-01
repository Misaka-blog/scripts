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

menu(){
    clear
    echo "#############################################################"
    echo -e "#                 ${RED} WARP 配置文件一键生成脚本${PLAIN}                #"
    echo -e "# ${GREEN}作者${PLAIN}: MisakaNo の 小破站                                  #"
    echo -e "# ${GREEN}博客${PLAIN}: https://blog.misaka.rest                            #"
    echo -e "# ${GREEN}GitHub 项目${PLAIN}: https://github.com/Misaka-blog               #"
    echo -e "# ${GREEN}Telegram 频道${PLAIN}: https://t.me/misakanocchannel              #"
    echo -e "# ${GREEN}Telegram 群组${PLAIN}: https://t.me/misakanoc                     #"
    echo -e "# ${GREEN}YouTube 频道${PLAIN}: https://www.youtube.com/@misaka-blog        #"
    echo "#############################################################"
    echo ""
    echo ""
    echo -e "  ${GREEN}1.${PLAIN} ${RED}注册 WARP API${PLAIN}"
    echo " -------------"
    echo -e "  ${GREEN}2.${PLAIN} 生成 WireGuard 配置"
    echo -e "  ${GREEN}3.${PLAIN} 生成 Sing-box 配置"
    echo ""
    read -rp " 请选择操作 [0-9]：" answer
    case $answer in
        1) installHysteria ;;
        2) uninstall ;;
    esac
}

menu