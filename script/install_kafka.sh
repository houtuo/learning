#!/bin/bash
################################################################
## File Name: install_kafka.sh
## Version: V2.0
## Author: houtuo
## Mail: tuo.hou@rklink.cn
## Created Time: 2019-04-16 10:10:30
## Last Modified: 2025-12-17
## Description: 安装kafka
###############################################################
#支持在线和离线安装安装

KAFKA_VERSION=3.9.1
SCALA_VERSION=2.13
KAFKA_URL="https://mirrors.tuna.tsinghua.edu.cn/apache/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"

ZK_VERSOIN=3.9.4
ZK_URL="https://mirrors.tuna.tsinghua.edu.cn/apache/zookeeper/zookeeper-${ZK_VERSOIN}/apache-zookeeper-${ZK_VERSOIN}-bin.tar.gz"

ZK_INSTALL_DIR=/usr/local/zookeeper
KAFKA_INSTALL_DIR=/usr/local/kafka

NODE1=10.0.0.13
NODE2=10.0.0.14
NODE3=10.0.0.15

HOST=`hostname -I|awk '{print $1}'`
.  /etc/os-release

color () {
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
    SETCOLOR_NORMAL="echo -en \E[0m"
    echo -n "$1" && $MOVE_TO_COL
    echo -n "["
    if [ $2 = "success" -o $2 = "0" ] ;then
        ${SETCOLOR_SUCCESS}
        echo -n $"  OK  "    
    elif [ $2 = "failure" -o $2 = "1"  ] ;then 
        ${SETCOLOR_FAILURE}
        echo -n $"FAILED"
    else
        ${SETCOLOR_WARNING}
        echo -n $"WARNING"
    fi
    ${SETCOLOR_NORMAL}
    echo -n "]"
    echo 
}

install_jdk() {
    if [ $ID = 'centos' -o  $ID = 'rocky' ];then
        yum -y install java-1.8.0-openjdk-devel || { color "安装JDK失败!" 1; exit 1; }
    else
        apt update
        apt install openjdk-8-jdk -y || { color "安装JDK失败!" 1; exit 1; } 
    fi
    java -version
}

zk_myid () {
    read -p "请输入node编号(默认为 1): " MYID

    if [ -z "$MYID" ] ;then
        MYID=1
    elif [[ ! "$MYID" =~ ^[0-9]+$ ]];then
        color  "请输入正确的node编号!" 1
        exit
    else
        true
    fi
}

install_zookeeper() {
    wget -P /usr/local/src/ $ZK_URL || { color  "下载失败!" 1 ;exit ; }
    tar xf /usr/local/src/${ZK_URL##*/} -C `dirname ${ZK_INSTALL_DIR}`
    ln -s /usr/local/apache-zookeeper-*-bin/ ${ZK_INSTALL_DIR}
    echo "PATH=${ZK_INSTALL_DIR}/bin:$PATH" >  /etc/profile.d/zookeeper.sh
    .  /etc/profile.d/zookeeper.sh
    mkdir -p ${ZK_INSTALL_DIR}/data 
    echo $MYID > ${ZK_INSTALL_DIR}/data/myid
    cat > ${ZK_INSTALL_DIR}/conf/zoo.cfg <<EOF
tickTime=2000
initLimit=10
syncLimit=5
dataDir=${ZK_INSTALL_DIR}/data
clientPort=2181
maxClientCnxns=128
autopurge.snapRetainCount=3
autopurge.purgeInterval=24
server.1=${NODE1}:2888:3888
server.2=${NODE2}:2888:3888
server.3=${NODE3}:2888:3888
EOF
   
	cat > /lib/systemd/system/zookeeper.service <<EOF
[Unit]
Description=zookeeper.service
After=network.target

[Service]
Type=forking
#Environment=${ZK_INSTALL_DIR}
ExecStart=${ZK_INSTALL_DIR}/bin/zkServer.sh start
ExecStop=${ZK_INSTALL_DIR}/bin/zkServer.sh stop
ExecReload=${ZK_INSTALL_DIR}/bin/zkServer.sh restart

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now  zookeeper.service
    systemctl is-active zookeeper.service
    if [ $? -eq 0 ] ;then 
        color "zookeeper 安装成功!" 0  
    else 
        color "zookeeper 安装失败!" 1
        exit 1
    fi  
}


install_kafka(){
    if [ ! -f kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz ];then
        wget -P /usr/local/src  $KAFKA_URL  || { color  "下载失败!" 1 ;exit ; }
    else
        cp kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz /usr/local/src/
    fi
    tar xf /usr/local/src/${KAFKA_URL##*/}  -C /usr/local/
    ln -s ${KAFKA_INSTALL_DIR}_*/ ${KAFKA_INSTALL_DIR}
    echo PATH=${KAFKA_INSTALL_DIR}/bin:'$PATH' > /etc/profile.d/kafka.sh
    . /etc/profile.d/kafka.sh
   
    cat > ${KAFKA_INSTALL_DIR}/config/server.properties <<EOF
broker.id=$MYID
listeners=PLAINTEXT://${HOST}:9092
log.dirs=${KAFKA_INSTALL_DIR}/data
num.partitions=1
log.retention.hours=168
zookeeper.connect=${NODE1}:2181,${NODE2}:2181,${NODE3}:2181
zookeeper.connection.timeout.ms=6000
EOF
    mkdir ${KAFKA_INSTALL_DIR}/data
	 
    cat > /lib/systemd/system/kafka.service <<EOF
[Unit]                                                                          
Description=Apache kafka
After=network.target

[Service]
Type=simple
#Environment=JAVA_HOME=/data/server/java
#PIDFile=${KAFKA_INSTALL_DIR}/kafka.pid
ExecStart=${KAFKA_INSTALL_DIR}/bin/kafka-server-start.sh  ${KAFKA_INSTALL_DIR}/config/server.properties
ExecStop=/bin/kill  -TERM \${MAINPID}
Restart=always
RestartSec=20

[Install]
WantedBy=multi-user.target

EOF
	systemctl daemon-reload
	systemctl enable --now kafka.service
	#kafka-server-start.sh -daemon ${KAFKA_INSTALL_DIR}/config/server.properties 
	systemctl is-active kafka.service
	if [ $? -eq 0 ] ;then 
        color "kafka 安装成功!" 0  
    else 
        color "kafka 安装失败!" 1
        exit 1
    fi    
}

main(){
  zk_myid
  install_jdk
  install_zookeeper
  install_kafka
}  

# 调用main函数
main
