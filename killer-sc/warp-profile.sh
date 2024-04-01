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

reg_goapi(){
    wget -N https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-api/main-linux-amd64
    chmod +x main-linux-amd64
    wget -N https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-go/warp-go-latest-linux-amd64
    chmod +x warp-go-latest-linux-amd64

    # 运行 WARP API
    result_output=$(./main-linux-amd64)

    # 从结果获取设备 ID、私钥及 WARP TOKEN
    device_id=$(echo "$result_output" | awk -F ': ' '/device_id/{print $2}')
    private_key=$(echo "$result_output" | awk -F ': ' '/private_key/{print $2}')
    warp_token=$(echo "$result_output" | awk -F ': ' '/token/{print $2}')

    # 写入 WARP-GO 配置文件
    cat << EOF > warp.conf
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

    green "WARP API 账户注册成功！"
    menu
}

wg_gen(){
    apt-get install -y qrencode

    if [[ ! -f warp-go-latest-linux-amd64 ]]; then
        red "请先执行 1 选项注册账号之后再使用本选项！"
    fi

    result=$(/opt/warp-go/warp-go --config=warp.conf --export-wireguard=wireguard.conf) && sleep 5
    if [[ ! $result == "Success" ]]; then
        red "WARP 的 WireGuard 配置文件生成失败！"
        menu
    fi

    green "WARP 的 WireGuard 配置文件已提取成功！"
    yellow "节点配置文件内容如下"
    red "$(cat /root/warpgo-proxy.conf)"
    echo ""
    yellow "节点配置二维码如下所示："
    qrencode -t ansiutf8 </root/warpgo-proxy.conf

    read -p "按回车键返回" continue
    [[ $continue != "114514abcdef" ]] && menu
}

sb_gen(){
    if [[ ! -f warp-go-latest-linux-amd64 ]]; then
        red "请先执行 1 选项注册账号之后再使用本选项！"
    fi

    result=$(/opt/warp-go/warp-go --config=warp.conf --export-singbox=sing-box.json) && sleep 5
    if [[ ! $result == "Success" ]]; then
        red "WARP 的 Sing-box 配置文件生成失败！"
        menu
    fi

    green "WARP 的 Sing-box 配置文件已提取成功！"
    yellow "文件内容如下"
    red "$(cat /root/warpgo-sing-box.json)"

    read -p "按回车键返回" continue
    [[ $continue != "114514abcdef" ]] && menu
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