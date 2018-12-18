#!/bin/bash


function join () {

    local IFS="$1"; shift; echo "$*"; 

}


function run_ssh_cmd () {
    local SSHUSER_HOST=$1
    local SSHKEY=$2
    local CMD=$3
    ssh -t -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' -i $SSHKEY $SSHUSER_HOST "$CMD" 2>&1
}

function upload_file_scp () {

    local SSHUSER_HOST=$1
    local SSHKEY=$2
    local SOURCE=$3
    local DESTINATION=$4

    scp -r -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' -i $SSHKEY $SOURCE $SSHUSER_HOST:$DESTINATION 2>&1
}

function download_file_scp () {

    local SSHUSER_HOST=$1
    local SSHKEY=$2
    local SOURCE=$3
    local DESTINATION=$4

    scp -r -o 'PasswordAuthentication no' -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' -i $SSHKEY $SSHUSER_HOST:$SOURCE $DESTINATION 2>&1
}

function ensure_remote_ssh_key () {
    local SSH_HOST=$1
    local SSHKEY=$2

    local SSHKEY_BASENAME=$(basename $SSHKEY)

    if [[ ! -f "/tmp/${SSHKEY_BASENAME}" ]]; then
        upload_file_scp $SSH_HOST $SSHKEY $SSHKEY "/tmp/${SSHKEY_BASENAME}"
    fi

}

function run_windows_ssh_cmd () {

    # Since we don't have public IPs to windows nodes, we run wsmancmd trough the ansible node
    local SSH_HOST=$1
    local SSHKEY=$2

    local SSH_WIN_HOST=$3
    local CMD=$4

    local REMOTE_SSHKEY="/tmp/$(basename $SSHKEY)"
    local REMOTECMD="ssh -t -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' -i ${REMOTE_SSHKEY} $SSH_WIN_HOST $CMD 2>&1"

    ensure_remote_ssh_key $SSH_HOST $SSHKEY

    run_ssh_cmd $SSH_HOST $SSHKEY "$REMOTECMD"
}

function download_windows_file () {

    local SSH_HOST=$1
    local SSHKEY=$2

    local SSH_WIN_HOST=$3
    local SOURCE=$4
    # note, destination refers to the local folder on the caller machine ( not the ssh jumpbox )
    local DESTINATION=$5

    local REMOTE_DESTINATION="/tmp/$(basename $DESTINATION)"
    local REMOTE_SSHKEY="/tmp/$(basename $SSHKEY)"
    local REMOTECMD="scp -r -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' -i ${REMOTE_SSHKEY} $SSH_WIN_HOST:${SOURCE} ${REMOTE_DESTINATION} 2>&1"

    ensure_remote_ssh_key $SSH_HOST $SSHKEY

    run_ssh_cmd $SSH_HOST $SSHKEY "$REMOTECMD"

    download_file_scp $SSH_HOST $SSHKEY $REMOTE_DESTINATION $DESTINATION # Note, remote destination is actually the source

}

function upload_windows_file () {

    local SSH_HOST=$1
    local SSHKEY=$2

    local SSH_WIN_HOST=$3
    local SOURCE=$4
    # note, destination refers to the local folder on the caller machine ( not the ssh jumpbox )
    local DESTINATION=$5

    local REMOTE_SOURCE="/tmp/$(basename $SOURCE)"
    local REMOTE_SSHKEY="/tmp/$(basename $SSHKEY)"
    local REMOTECMD="scp -r -o 'StrictHostKeyChecking no' -o 'UserKnownHostsFile /dev/null' -i ${REMOTE_SSHKEY} ${REMOTE_SOURCE} $SSH_WIN_HOST:${DESTINATION} 2>&1"

    ensure_remote_ssh_key $SSH_HOST $SSHKEY

    upload_file_scp $SSH_HOST $SSHKEY $SOURCE $REMOTE_SOURCE
    run_ssh_cmd $SSH_HOST $SSHKEY "$REMOTECMD"

}