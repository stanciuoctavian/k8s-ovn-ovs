#!/bin/bash

# This script creates instances based on a ini file
#
# The options are:
#     --config /path/to/config/file # this should be the config ini file
#     --clean                       # will destroy the instances if they exist
#     --down                        # will just delete the instances

set -e

set -o pipefail

declare -a WINDOWS_NODES
declare -a LINUX_NODES

WINDOWS_USER_DATA=""
LINUX_USER_DATA=""

PRIVATE_KEY=""
KEY_NAME=""

WINDOWS_FLAVOR=""
LINUX_FLAVOR=""

NETWORK_PRIVATE=""
NETWORK_PUBLIC=""

function read-config() {
    local config="$1"

    WINDOWS_NODES=$(crudini --get $config windows server-names)
    LINUX_NODES=$(crudini --get $config linux server-names)

    WINDOWS_USER_DATA=$(crudini --get $config windows user-data)
    LINUX_USER_DATA=$(crudini --get $config linux user-data)

    WINDOWS_FLAVOR=$(crudini --get $config windows flavor)
    LINUX_FLAVOR=$(crudini --get $config linux flavor)

    WINDOWS_IMAGE=$(crudini --get $config windows image)
    LINUX_IMAGE=$(crudini --get $config linux image)
    
    PRIVATE_KEY=$(crudini --get $config keys private)
    KEY_NAME=$(crudini --get $config keys name)

    NETWORK_INTERNAL=$(crudini --get $config network internal)
    NETWORK_EXTERNAL=$(crudini --get $config network external)

    echo "CONFIG IS:"
    echo "----------------------------------------------"
    echo "Windows nodes are:        $WINDOWS_NODES"
    echo "Windows user data script: $WINDOWS_USER_DATA"
    echo "Windows flavor:           $WINDOWS_FLAVOR"
    echo "Windows image:            $WINDOWS_IMAGE"
    echo "----------------------------------------------"
    echo "Linux nodes are:          $LINUX_NODES"
    echo "Linux user data script:   $LINUX_USER_DATA"
    echo "Linux flavor:             $LINUX_FLAVOR"
    echo "Linux image:              $LINUX_IMAGE"
    echo "----------------------------------------------"
    echo "Public key: $PUBLIC_KEY"
    echo "Private key: $PRIVATE_KEY"
    echo "----------------------------------------------"
}

function delete-previous-cluster () {
    IFS=","
    for server in $WINDOWS_NODES; do
        echo "Now deleting : $server"
        ip=$(openstack server show $server | grep address | awk '{print $5}')
        openstack server delete "$server"
        openstack floating ip delete $ip
    done
    for server in $LINUX_NODES; do
        echo "Now deleting : $server"
        ip=$(openstack server show $server | grep address | awk '{print $5}')
        openstack server delete "$server"
        openstack floating ip delete $ip
    done
    IFS=$" "
}

function create-cluster () {
    IFS=","
    for server in $WINDOWS_NODES; do
        echo "Now booting : $server"
        nova boot --flavor $WINDOWS_FLAVOR --image $WINDOWS_IMAGE --nic net-id=$NETWORK_INTERNAL --key $KEY_NAME --user-data $WINDOWS_USER_DATA $server > /dev/null
        ip=$(openstack floating ip create $NETWORK_EXTERNAL | grep " name " | awk '{print $4}')
        openstack server add floating ip $server $ip
    done
    for server in $LINUX_NODES; do
        echo "Now booting : $server"
        nova boot --flavor $LINUX_FLAVOR --image $LINUX_IMAGE --nic net-id=$NETWORK_INTERNAL --key $KEY_NAME --user-data $LINUX_USER_DATA $server > /dev/null
        ip=$(openstack floating ip create $NETWORK_EXTERNAL | grep " name " | awk '{print $4}')
        openstack server add floating ip $server $ip
    done
    IFS=$" "
}

function generate-report () {
    echo "REPORT:"
    echo "Linux servers created:"
    IFS=","
    for server in $LINUX_NODES; do
        ip=$(openstack server show $server | grep address | awk '{print $5}')
        echo "$server | $ip"
    done
    echo "----------------------------------------------"
    echo "Windows servers created:"
    for server in $WINDOWS_NODES; do
        ip=$(openstack server show $server | grep address | awk '{print $5}')
        pass=$(nova get-password $server $PRIVATE_KEY)
        echo "$server | $ip | $pass"
    done
    echo "----------------------------------------------"
    IFS=$" "
}

function main() {
	
    TEMP=$(getopt -o c:x::d:: --long config:,clean::,down:: -n '' -- "$@")
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    echo $TEMP
    eval set -- "$TEMP"

    while true ; do
        case "$1" in
            --config)
                CONFIG="$2";  shift 2;;
            --clean)
                CLEAN="true"; shift 2;;
            --down)
                DOWN="true";  shift 2;;
            --) shift ; break ;;
        esac
    done

    read-config "$CONFIG"
    if [[ $CLEAN == "true" ]]; then
        delete-previous-cluster
    fi
    if [[ $DOWN == "true" ]]; then
        delete-previous-cluster
        exit 0
    fi
    create-cluster
    generate-report
}

main "$@"
