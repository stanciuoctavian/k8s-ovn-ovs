#!/bin/bash

set -e

set -o pipefail

declare -a LINUX_NODES
declare -a WINDOWS_NODES

declare -a LINUX_IP
declare -a WINDOWS_IP

declare -a PASSWORDS

PRIVATE_KEY=""

function wait-user-data () {
    echo "Waiting for crudini to be available"
    while true; do
        x=$(which crudini || true)
        if [[ -z $x ]]; then
            sleep 5
        else
            break
        fi
    done
}

function read-report () {
    local report="$1"

    echo "Reading report"
    IFS=$","
    WINDOWS=$(crudini --get $report windows server-names)
    LINUX=$(crudini --get $report linux server-names)
    WINDOWS_NODES=($WINDOWS)
    LINUX_NODES=($LINUX)

    WINDOWS=$(crudini --get $report windows ips)
    LINUX=$(crudini --get $report linux ips)
    WINDOWS_IP=($WINDOWS)
    LINUX_IP=($LINUX)

    WINDOWS=$(crudini --get $report windows passwords)
    PASSWORDS=($WINDOWS)
    IFS=$" "
}

function clone-repo () {
    local repo="$1"; shift
    local destination="$1"

    echo "Cloning repo"
    git clone $repo "$destination"
    pushd "$destination"
        git checkout update_ansible
    popd
}
 
function populate-etc-hosts () {
    local length_linux=${#LINUX_NODES[@]}
    local length_windows=${#WINDOWS_NODES[@]}

    echo "Populating /etc/hosts"
    for (( i=0; i < $length_linux; i++ )); do
        printf "%s %s\n" "${LINUX_IP[$i]}" "${LINUX_NODES[$i]}" | sudo tee -a /etc/hosts
    done
    for (( i=0; i < $length_windows; i++ )); do
        printf "%s %s\n" "${WINDOWS_IP[$i]}" "${WINDOWS_NODES[$i]}" | sudo tee -a /etc/hosts
    done
}

function populate-ansible-hosts () {
    local file="$1"

    echo "Populating ansible invetory hosts"
    sed -i "s/node.//g" "$file"
    let i=1
    for server in ${LINUX_NODES[@]}; do
        if [[ $i == "1" ]]; then
            sed -i "/\[kube-master\]/a $server" "$file"
        else
            sed -i "/\[kube-minions-linux\]/a $server" "$file"
        fi
        i=$((i + 1))
    done
    for server in ${WINDOWS_NODES[@]}; do
        sed -i "/\[kube-minions-windows\]/a $server" "$file"
    done
}

function configure-linux-connection () {
    local file_master="$1"; shift
    local file_minions="$1"

    echo "Configure ansible to use ssh key for linux minions"
    sed -i "/ubuntu/a ansible_ssh_private_key_file: ~\/id_rsa" $file_master
    sed -i "/ubuntu/a ansible_ssh_private_key_file: ~\/id_rsa" $file_minions
}

function create-windows-login-file () {
    local template='ansible_user: admin\nansible_password: %s'

    echo "Creating individual file for windows minions(winrm)"
    length=${#WINDOWS_NODES[@]}
    for (( i=0; i < $length; i++ )); do
        printf "$template" ${PASSWORDS[$i]} > "ovn-kubernetes/contrib/inventory/host_vars/${WINDOWS_NODES[$i]}"
    done
}

function ssh-key-scan () {
    echo "ssh keyscan for linux minions"
    for server in ${LINUX_NODES[@]}; do
        ssh-keyscan $server >> ~/.ssh/known_hosts
        sudo bash -c "ssh-keyscan $server >> /root/.ssh/known_hosts"
    done
}

function deploy-k8s-cluster () {
    echo "starting kubernetes deployment"
    sudo cp /home/ubuntu/id_rsa /root/
    pushd "ovn-kubernetes/contrib"
        while true; do
            if ansible -m setup all > /dev/null; then
                break
            else 
                sleep 5
            fi
        done
        sudo bash -c "ansible-playbook ovn-kubernetes-cluster.yml"
    popd
}

function main () {
    TEMP=$(getopt -o r: --long report: -n 'ansible-script.sh' -- "$@")
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    echo $TEMP
    eval set -- "$TEMP"

    while true ; do
        case "$1" in
            --report)
                report="$2";           shift 2;;
            --) shift ; break ;;
        esac
    done

    wait-user-data
    read-report "$report"
    clone-repo "https://github.com/alinbalutoiu/ovn-kubernetes.git" "./ovn-kubernetes"
    populate-etc-hosts
    populate-ansible-hosts "./ovn-kubernetes/contrib/inventory/hosts"
    configure-linux-connection "./ovn-kubernetes/contrib/inventory/group_vars/kube-master" \
        "./ovn-kubernetes/contrib/inventory/group_vars/kube-minions-linux"
    create-windows-login-file
    ssh-key-scan
    deploy-k8s-cluster
}

main "$@"
