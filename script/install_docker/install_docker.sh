#!/bin/bash
##############################################################
# File Name: docker_install.sh
# Version: V1.0
# Author: houtuo
# Mail: tuo.hou@rklink.cn
# Created Time : 2024-03-1 10:10:30
# Description: 安装docker
##############################################################
# 加载操作系统环境
source /etc/profile
# 统一使用英文的UTF-8字符集
export LANG=en_US.UTF-8
if [ $UID -ne 0 ];then
    echo "需要使用root用户执行脚本"
    exit 1
fi

DIR=`pwd`
PACKAGE_NAME="docker-23.0.1.tgz"
DOCKER_FILE=${DIR}/${PACKAGE_NAME}

function docker_install(){
    docker --version 2>/dev/null
    if [ $? -eq 0 ];then
        echo "Docker已经安装"
    else
        grep "Kernel" /etc/issue &> /dev/null
        if [ $? -eq 0 ];then
            /bin/echo  "当前系统是cat /etc/redhat-release,即将开始系统初始化、配置docker-compose与安装docker" && sleep 1

            /bin/tar -xvf ${DOCKER_FILE}
            \cp docker/*  /usr/bin
            \cp containerd.service /lib/systemd/system/containerd.service
            \cp docker.service  /lib/systemd/system/docker.service
            \cp docker.socket /lib/systemd/system/docker.socket
            \cp ${DIR}/docker-compose-linux-x86_64 /usr/bin/docker-compose
            chmod 755 /usr/bin/docker-compose
            groupadd docker && useradd docker -g docker
            systemctl  enable --now containerd.service
            systemctl  enable --now docker.service
            systemctl  enable --now docker.socket   
            docker --version                                 
        fi
    fi
}

function main(){
    docker_install    
}  

# 调用main函数
main
