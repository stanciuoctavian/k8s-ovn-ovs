#!/bin/bash

set -e
set -x

set -o pipefail

K8S_MASTER_IP=""
ID_RSA=""

function configure-kubectl () {
    mkdir -p scp
    ssh -i $ID_RSA $K8S_MASTER_IP mkdir -p ~/scp
    ssh -i $ID_RSA $K8S_MASTER_IP sudo cp -r /etc/kubernetes/* ~/scp
    ssh -i $ID_RSA $K8S_MASTER_IP sudo cp /root/.kube/config ~/scp
    ssh -i $ID_RSA $K8S_MASTER_IP sudo chown -R ubuntu:ubuntu ~/scp
    scp -r -i $ID_RSA $K8S_MASTER_IP:~/scp/* scp/

    mkdir -p ~/.kube
    sudo mkdir -p /etc/kubernetes/tls

    cp ~/scp/config ~/.kube/
    sudo cp ~/scp/tls/* /etc/kubernetes/tls
    sudo chmod 0644 /etc/kubernetes/tls/*
}

function install-kubectl () {
    local kubectl_version

    sudo apt-get update && sudo apt-get install apt-transport-https -y
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubectl

    kubectl_version=$(kubectl version | grep Server | awk '{print $5}' | tr "\"" " " | awk '{print $2}')
    kubectl_version=${kubectl_version#v}
    kubectl_version="${kubectl_version}-00"

    sudo apt-get install kubectl=$kubectl_version -y --allow-downgrades
}

function install-go() {
    echo "Installing golang"

    DEBIAN_FRONTEND=noninteractive sudo apt-get install golang-$GO_VERSION-go -y
    mkdir -p $HOME/go/{bin,pkg,src}

    local template="""
export GOROOT=/usr/lib/go-1.10
export GOBIN=/usr/lib/go-1.10/bin
export GOPATH=/home/ubuntu/go
export PATH=/usr/lib/go-1.10/bin:$PATH:/home/ubuntu/go/bin;
"""
    echo $template >> ~/.bashrc    
}

function program-is-installed() {
    local return_=1
    type $1 >/dev/null 2>&1 || { local return_=0; }
    echo "$return_"
}

function install-docker(){
    if [[ $(program_is_installed docker) != "1" ]]; then
        echo "Installing docker"
        DEBIAN_FRONTEND=noninteractive sudo apt-get install docker.io -y

        echo "Adding user $USER to docker group"
        sudo usermod -a -G docker $USER
    fi
}

function clone-k8s() {
    KUBE_REPO="http://github.com/e2e-win/kubernetes"
    if [ ! -d "run-e2e/kubernetes" ]; then
        echo "Cloning Kubernetes repo $KUBE_REPO"
        git clone $KUBE_REPO run-e2e/kubernetes
    fi
}

function build-k8s-parts () {
    sudo run-e2e/kubernetes/build/run.sh make WHAT="test/e2e/e2e.test  cmd/kubectl vendor/github.com/onsi/ginkgo/ginkgo"
}

function install-bazel () {
    if [[ -z $(which bazel) ]]; then
        sudo apt-get install unzip -y
        if [[ ! -a  bazel-0.18.0-installer-linux-x86_64.sh ]]; then
            wget https://github.com/bazelbuild/bazel/releases/download/0.18.0/bazel-0.18.0-installer-linux-x86_64.sh
        fi
        chmod +x bazel-0.18.0-installer-linux-x86_64.sh
        ./bazel-0.18.0-installer-linux-x86_64.sh --user
    fi
}

function build-kubetest () {
    if [[ ! -d test-infra ]]; then
        git clone https://github.com/e2e-win/test-infra.git
    fi
    pushd test-infra
        export PATH="$PATH:$HOME/bin"
        bazel build //kubetest
        sudo cp bazel-bin/kubetest/linux_amd64_stripped/kubetest /usr/bin
    popd
}

function populate-kube-env () {
    sed -i "s/KUBE_MASTER=/&local/" run-e2e/kube-env
    sed -i "s/KUBE_MASTER_IP=/&$K8S_MASTER_IP/" run-e2e/kube-env
    sed -i "s/KUBE_MASTER_URL=/&https:\/\/$K8S_MASTER_IP/" run-e2e/kube-env
    sed -i "s/KUBECONFIG=/&\/home\/ubuntu\/.kube\/config/" run-e2e/kube-env
    sed -i "s/KUBE_TEST_REPO_LIST=/&\/home\/ubuntu\/run-e2e\/repo-list.yaml/" run-e2e/kube-env
}

function start-tests () {
    pushd run-e2e
        set -x
        source kube-env
        export KUBECTL_PATH=$(which kubectl)
        focus=$(cat focus)
        skip=$(cat skip)
        mkdir -p results
        pushd kubernetes
            kubetest --ginkgo-parallel=4 --verbose-commands=true --provider=local --test \
                --test_args="--ginkgo.dryRun=false --ginkgo.focus=$(eval $focus) --ginkgo.skip=$(eval $skip)" --dump=../results/ \
                | tee ../results/kubetest.log
        popd
    popd
}

function main () {
    TEMP=$(getopt -o i:k::d::a::p: --long k8s-master-ip:,id-rsa: -n '' -- "$@")
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    echo $TEMP
    eval set -- "$TEMP"
    
    while true ; do
        case "$1" in
            --k8s-master-ip)
                K8S_MASTER_IP="$2";    shift 2;;
            --id-rsa)
                ID_RSA="$2";           shift 2;;
            --) shift ; break ;;
        esac
    done

    configure-kubectl
    install-kubectl
    install-go
    install-docker
    clone-k8s
    build-k8s-parts
    install-bazel
    build-kubetest
    populate-kube-env
    start-tests
}

main "$@"
