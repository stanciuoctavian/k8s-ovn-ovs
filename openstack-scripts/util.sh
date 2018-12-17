#!/bin/bash

function run_wsmancmd () {
    
    local HOST=$1
    local USERNAME=$2
    local PASSWORD=$3
    local CMD=$4

    $BASEDIR/wsmancmd.py -U https://$HOST:5986/wsman -u $USERNAME -p $PASSWORD $CMD

}

function join () {

    local IFS="$1"; shift; echo "$*"; 

}


function run_ssh_cmd () {
    SSHUSER_HOST=$1
    SSHKEY=$2
    CMD=$3
    ssh -t -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' -i $SSHKEY $SSHUSER_HOST "$CMD" 2>&1
}