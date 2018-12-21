#!/bin/bash

set -e

set -o pipefail

declare -a LINUX_NODES
declare -a WINDOWS_NODES

declare -a LINUX_IP
declare -a WINDOWS_IP

declare -a PASSWORDS

PRIVATE_KEY=""
ID_RSA=""

. util.sh

function read-report () {
    local report="$1"

    echo "Reading report"
    echo "$report"
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

    KUBERNETES_REMOTE=$(crudini --get $report kubernetes noremote)
    KUBERNETES_COMMIT=$(crudini --get $report kubernetes commit)

    IFS=$" "
}

function configure-kubectl () {
    mkdir -p scp
    ssh -i $ID_RSA ${LINUX_NODES[0]} mkdir -p ~/scp
    ssh -i $ID_RSA ${LINUX_NODES[0]} sudo cp -r /etc/kubernetes/* ~/scp
    ssh -i $ID_RSA ${LINUX_NODES[0]} sudo cp /root/.kube/config ~/scp
    ssh -i $ID_RSA ${LINUX_NODES[0]} sudo chown -R ubuntu:ubuntu ~/scp
    scp -r -i $ID_RSA ${LINUX_NODES[0]}:~/scp/* scp/

    mkdir -p ~/.kube
    sudo mkdir -p /etc/kubernetes/tls

    cp ~/scp/config ~/.kube/
    sudo cp ~/scp/tls/* /etc/kubernetes/tls
    sudo chmod 0644 /etc/kubernetes/tls/*
}

function program-is-installed () {
    local return_=1
    type $1 >/dev/null 2>&1 || { local return_=0; }
    echo "$return_"
}

function build-k8s-parts () {
    echo "Building Kubernetes"
    pushd ~/go/src/k8s.io/kubernetes
        git checkout master --force
        # Building kubernetes produces lots of output. Only keep errors
        sudo ./build/run.sh make WHAT="test/e2e/e2e.test vendor/github.com/onsi/ginkgo/ginkgo" 1> /dev/null
    popd
}

function get-kubetest () {
    source ~/.bashrc
    export GOROOT=/usr/lib/go
    export GOBIN=/usr/lib/go/bin
    export GOPATH=/home/ubuntu/go
    export PATH=/home/ubuntu/bin:/usr/lib/go/bin:$PATH:/home/ubuntu/go/bin
    go get -u k8s.io/test-infra/kubetest
}

function populate-kube-env () {
    sed -i "s/KUBE_MASTER=/&local/" run-e2e/kube-env
    sed -i "s/KUBE_MASTER_IP=/&${LINUX_NODES[0]}/" run-e2e/kube-env
    sed -i "s/KUBE_MASTER_URL=/&https:\/\/${LINUX_NODES[0]}/" run-e2e/kube-env
    sed -i "s/KUBECONFIG=/&\/home\/ubuntu\/.kube\/config/" run-e2e/kube-env
    sed -i "s/KUBE_TEST_REPO_LIST=/&\/home\/ubuntu\/run-e2e\/repo-list.yaml/" run-e2e/kube-env
}

function taint-node () {
    kubectl taint nodes ${LINUX_NODES[1]} key=value:NoSchedule
    kubectl label nodes ${LINUX_NODES[1]} node-role.kubernetes.io/master=NoSchedule
}

function get-service-logs () {
    node=$1; shift
    services="$1"; shift

    for service in $services; do
         run_ssh_cmd "ubuntu@$node" "$PRIVATE_KEY" "journalctl -u $service.service" > $node.$service.log.$(date +%Y.%m.%d.%M.%S)
    done
}

function increment-path () {
    name="$1"
    if [[ -d $name ]] || [[ -e $name ]]; then
        i=1
        while [[ -d $name-old-$i ]] || [[ -e $name-old-$i ]]; do
            let i++
        done
        name2=$name-old-$i
    fi
    mv $name $name2
}

function collect-logs () {
    pushd run-e2e
        mkdir -p results
        pushd results

            mkdir -p k8s-master-logs
            pushd k8s-master-logs
                get-service-logs "${LINUX_NODES[0]}" "kube-apiserver kube-scheduler kube-controller-manager ovn-central ovn-host ovn-k8s-watcher"
                run_ssh_cmd "ubuntu@${LINUX_NODES[0]}" "$PRIVATE_KEY" "sudo chmod -R 777 /var/log/openvswitch"
                run_ssh_cmd "ubuntu@${LINUX_NODES[0]}" "$PRIVATE_KEY" "find /var/log/openvswitch -type f | sudo xargs chmod 644"
                increment-path openvswitch
                download_file_scp "ubuntu@${LINUX_NODES[0]}" "$PRIVATE_KEY" "/var/log/openvswitch" "."
            popd

            # get linux minion logs
            mkdir -p linux-minions-logs
            pushd linux-minions-logs
                length=${#LINUX_NODES[@]}
                for server in ${LINUX_NODES[@]:1:$length-1}; do
                    get-service-logs "$server" "kubelet ovn-host ovnkube-gateway-helper"
                    run_ssh_cmd "ubuntu@$server" "$PRIVATE_KEY" "sudo chmod -R 777 /var/log/openvswitch"
                    run_ssh_cmd "ubuntu@$server" "$PRIVATE_KEY" "find /var/log/openvswitch -type f | sudo xargs chmod 644"
                    increment-path openvswitch
                    download_file_scp "ubuntu@$server" "$PRIVATE_KEY" "/var/log/openvswitch" "."
                done
            popd

            # get windows minions logs
            mkdir -p windows-minions-logs
            pushd windows-minions-logs
                for server in ${WINDOWS_NODES[@]}; do
                    increment-path kubelet.log
                    download_file_scp "admin@$server" "$PRIVATE_KEY" '"C:/kubernetes/kubelet.log"' "."
                    increment-path ovn-kubernetes-node.log
                    download_file_scp "admin@$server" "$PRIVATE_KEY" '"C:/kubernetes/ovn-kubernetes-node.log"' "."
                    increment-path logs
                    download_file_scp "admin@$server" "$PRIVATE_KEY" '"C:/Program Files/Cloudbase Solutions/Open vSwitch/logs/"' "."
                done
            popd

        popd
    popd
}

function start-tests () {
    pushd run-e2e
        source kube-env
        focus=$(cat focus | sed 's:\\\\:\\:g')
        skip=$(cat skip | sed 's:\\\\:\\:g')
        mkdir -p results
        pushd ~/go/src/k8s.io/kubernetes

            kubetest --ginkgo-parallel=${GINKGO_PARALLEL} --verbose-commands=true --provider=skeleton --test \
                --test_args="--ginkgo.dryRun=false --ginkgo.focus=$focus --ginkgo.skip=$skip" --dump=~/run-e2e/results/ \
                | tee ~/run-e2e/results/kubetest.log
        popd
    popd
}

function main () {
    TEMP=$(getopt -o r:i: --long report:,id-rsa: -n '' -- "$@")
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    echo $TEMP
    eval set -- "$TEMP"
    
    while true ; do
        case "$1" in
            --report)
                report="$2";           shift 2;;
            --id-rsa)
                PRIVATE_KEY="$2";      shift 2;;
            --) shift ; break ;;
        esac
    done

    read-report "$report"
    configure-kubectl
    build-k8s-parts
    get-kubetest
    populate-kube-env
    taint-node
    collect-logs
    start-tests
    collect-logs
}

main "$@"
