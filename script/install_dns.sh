#!/bin/bash
###############################################################
# File Name: install_dns.sh
# Version: V2.0
# Author: houtuo
# Mail: tuo.hou@rklink.cn
# Created Time: 2019-04-16 10:10:30
# Last Modified: 2025-12-17
# Description: DNS服务器安装脚本
###############################################################

DOMAIN=rklink.cn
HOST=dns1
HOST_IP=10.0.0.10
LOCALHOST=`hostname -I | awk '{print $1}'`

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

install_dns () {
    if [ $ID = 'centos' -o $ID = 'rocky' ];then
	    yum install -y  bind bind-utils
	elif [ $ID = 'ubuntu' ];then
        apt update
        apt install -y bind9 bind9-utils bind9-host
	else
	    color "不支持此操作系统，退出!" 1
	    exit
	fi
    
}

config_dns () {
    if [ $ID = 'centos' -o $ID = 'rocky' ];then
	    sed -i -e '/listen-on/s/127.0.0.1/localhost/' -e '/allow-query/s/localhost/any/' -e 's/dnssec-enable yes/dnssec-enable no/' -e 's/dnssec-validation yes/dnssec-validation no/'  /etc/named.conf
        cat >> 	/etc/named.rfc1912.zones <<EOF
zone "$DOMAIN" IN {
    type master;
    file  "$DOMAIN.zone";
};
EOF
        cat > /var/named/$DOMAIN.zone <<EOF
\$TTL 1D
@	IN SOA	master admin (
					1	; serial
					1D	; refresh
					1H	; retry
					1W	; expire
					3H )	; minimum
	        NS	 master
master      A    ${LOCALHOST}         
$HOST     	A    $HOST_IP
EOF
        chmod 640 /var/named/$DOMAIN.zone
        chgrp named /var/named/$DOMAIN.zone
	elif [ $ID = 'ubuntu' ];then
        sed -i 's/dnssec-validation auto/dnssec-validation no/' /etc/bind/named.conf.options
        cat >> 	/etc/bind/named.conf.default-zones <<EOF
zone "$DOMAIN" IN {
    type master;
    file  "/etc/bind/$DOMAIN.zone";
};
EOF
        cat > /etc/bind/$DOMAIN.zone <<EOF
\$TTL 1D
@	IN SOA	master admin (
					1	; serial
					1D	; refresh
					1H	; retry
					1W	; expire
					3H )	; minimum
	        NS	 master
master      A    ${LOCALHOST}         
$HOST     	A    $HOST_IP
EOF
        chgrp bind  /etc/bind/$DOMAIN.zone
	else
	    color "不支持此操作系统，退出!" 1
	    exit
	fi
    
    

}

start_service () {
    systemctl enable named
    systemctl restart named
	systemctl is-active named.service
	if [ $? -eq 0 ] ;then 
        color "DNS 服务安装成功!" 0  
    else 
        color "DNS 服务安装失败!" 1
        exit 1
    fi   
}

main(){
  install_dns
  config_dns
  start_service
}  

# 调用main函数
main

