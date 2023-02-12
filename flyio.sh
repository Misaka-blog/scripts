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

clear
echo "#############################################################"
echo -e "#                ${RED} Fly.io xray 一键安装脚本${PLAIN}                  #"
echo -e "# ${GREEN}作者${PLAIN}: MisakaNo の 小破站                                  #"
echo -e "# ${GREEN}博客${PLAIN}: https://blog.misaka.rest                            #"
echo -e "# ${GREEN}GitHub 项目${PLAIN}: https://github.com/Misaka-blog               #"
echo -e "# ${GREEN}Telegram 频道${PLAIN}: https://t.me/misakablogchannel             #"
echo -e "# ${GREEN}Telegram 群组${PLAIN}: https://t.me/misakanoxpz                   #"
echo -e "# ${GREEN}YouTube 频道${PLAIN}: https://www.youtube.com/@misaka-blog        #"
echo "#############################################################"
echo ""

yellow "使用前请注意："
red "1. 我已知悉本项目有可能触发 Fly.io 封号机制"
red "2. 我不保证脚本其搭建节点的稳定性"
read -rp "是否安装脚本？ [Y/N]：" yesno

if [[ $yesno =~ Y|y ]]; then
    yellow "正在安装Flyctl命令行工具..."
    curl -L https://fly.io/install.sh | FLYCTL_INSTALL=/usr/local sh
    yellow "请复制以下链接，让Flyctl登录你的Fly.io账户"
    flyctl auth login
    if [[ -n $(flyctl auth token | grep "No access token available") ]]; then
        red "Fly.io 账户登录失败！脚本自动退出。"
        exit 1
    fi
else
    red "已退出安装！"
fi