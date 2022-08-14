#!/bin/bash

function create_properties_file() {

    local PGID=$1
    local PUID=$2
    local SUDO_ACCESS=$3
    local TZ=$4
    
    #Create temporal properties file
    ENV_PROPERTIES_FILE=$(mktemp)

    echo "${!PGID@}=$PGID" >> $ENV_PROPERTIES_FILE
    echo "${!PUID@}=$PUID" >> $ENV_PROPERTIES_FILE
    echo "${!SUDO_ACCESS@}=$SUDO_ACCESS" >> $ENV_PROPERTIES_FILE
    echo "${!TZ@}=$TZ" >> $ENV_PROPERTIES_FILE

    echo $ENV_PROPERTIES_FILE
}

function setup_default_environment() {

    : ${K8S_NAMESPACE_NAME:="default"} ${K8S_DRY_RUN:="true"} 
    : ${PGID:=1000} ${PUID:=1000} ${SUDO_ACCESS:=false} ${TZ:=$(cat /etc/timezone)} 
    : ${SSH_SERVER_PORT:=22}
}