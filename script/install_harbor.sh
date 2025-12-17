#!/bin/bash
###############################################################
# File Name: install_harbor.sh
# Version: V1.0
# Author: houtuo
# Mail: tuo.hou@rklink.cn
# Created Time: 2025-12-17 10:10:30
# Last Modified: 2025-12-17
# Description: 安装harbor脚本
###############################################################

HARBOR_VERSION=2.14.1
HARBOR_BASE=/usr/local
HARBOR_NAME=`hostname -I|awk '{print $1}'`
HARBOR_ADMIN_PASSWORD=123456
HARBOR_IP=`hostname -I|awk '{print $1}'`
COLOR_SUCCESS="echo -e \\033[1;32m"
COLOR_FAILURE="echo -e \\033[1;31m"
END="\033[m"

. /etc/os-release

color() {
    local RES_COL=60
    local message="$1"
    local type="$2"
    
    # 定义颜色代码
    local RED="\033[1;31m"
    local GREEN="\033[1;32m"
    local YELLOW="\033[1;33m"
    local RESET="\033[0m"
    
    # 输出消息
    printf "%s" "$message"
    
    # 移动到第60列
    printf "\033[%dG[" $RES_COL
    
    # 根据类型输出不同颜色的状态
    case $type in
        "success"|"0")
            printf "${GREEN}  OK  ${RESET}"
            ;;
        "failure"|"1")
            printf "${RED}FAILED${RESET}"
            ;;
        *)
            printf "${YELLOW}WARNING${RESET}"
            ;;
    esac
    
    printf "]\n"
}

install_harbor(){
    ${COLOR_SUCCESS}"开始安装 Harbor....."${END}
    sleep 1
    if  [ ! -e  harbor-offline-installer-v${HARBOR_VERSION}.tgz ] ;then
        wget https://github.com/goharbor/harbor/releases/download/v${HARBOR_VERSION}/harbor-offline-installer-v${HARBOR_VERSION}.tgz || ${COLOR_FAILURE} "下载失败!" ${END}
    fi
    [ -d ${HARBOR_BASE} ] ||  mkdir ${HARBOR_BASE}
    tar xvf harbor-offline-installer-v${HARBOR_VERSION}.tgz  -C ${HARBOR_BASE}
    cd ${HARBOR_BASE}/harbor
    cp harbor.yml.tmpl harbor.yml
    sed -ri "/^hostname/s/reg.mydomain.com/${HARBOR_NAME}/" harbor.yml
    sed -ri "/^https/s/(https:)/#\1/" harbor.yml
    sed -ri "s/(port: 443)/#\1/" harbor.yml
    sed -ri "/certificate:/s/(.*)/#\1/" harbor.yml
    sed -ri "/private_key:/s/(.*)/#\1/" harbor.yml
    sed -ri "s/Harbor12345/${HARBOR_ADMIN_PASSWORD}/" harbor.yml
    sed -i 's#^data_volume: /data#data_volume: /data/harbor#' harbor.yml
    ${HARBOR_BASE}/harbor/install.sh && ${COLOR_SUCCESS}"Harbor 安装完成"${END} ||  ${COLOR_FAILURE}"Harbor 安装失败"${END}
    cat > /lib/systemd/system/harbor.service <<EOF
[Unit]
Description=Harbor
After=docker.service systemd-networkd.service systemd-resolved.service
Requires=docker.service
Documentation=http://github.com/vmware/harbor

[Service]
Type=simple
Restart=on-failure
RestartSec=5
ExecStart=/usr/bin/docker-compose -f  ${HARBOR_BASE}/harbor/docker-compose.yml up
ExecStop=/usr/bin/docker-compose -f ${HARBOR_BASE}/harbor/docker-compose.yml down

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload 
    systemctl enable  harbor &>/dev/null ||  ${COLOR}"Harbor已配置为开机自动启动"${END}
    if [ $?  -eq 0 ];then  
        echo 
        color "Harbor安装完成!" 0
        echo "-------------------------------------------------------------------"
        echo -e "请访问链接: http://${HARBOR_IP}/" 
	    echo -e "用户和密码: admin/${HARBOR_ADMIN_PASSWORD}" 
    else
        color "Harbor安装失败!" 1
        exit
    fi
    echo "$HARBOR_IP     $HARBOR_NAME"   >> /etc/hosts
}


main(){
  install_harbor
}  

# 调用main函数
main
