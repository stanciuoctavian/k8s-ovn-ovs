#!/bin/bash

# This script is responsable for creating the config.ini file with job specific params and pass it on to the
# ./create-cluster.sh script

CREATE_CLUSTER_REPO="http://github.com/e2e-win/k8s-ovn-ovs"

DEFAULT_PROW_JOB_ID="00-00"
DEFAULT_BUILD_ID="0000"

mkdir -p $HOME/.ssh
touch $HOME/.ssh/known_hosts

function clone-repo() {
	REPO=$1
	BRANCH=${2:-"master"}

	git clone -b ${BRANCH} ${REPO}

}


clone-repo $CREATE_CLUSTER_REPO "dev"
pushd k8s-ovn-ovs/openstack-scripts

VM_PREFIX="${PROW_JOB_ID:-DEFAULT_PROW_JOB_ID}-${BUILD_ID:-DEFAULT_BUILD_ID}"

LINUX_MASTER="${VM_PREFIX}-master"
LINUX_MINION="${VM_PREFIX}-lin-minion"
WIN_MINION1="${VM_PREFIX}-win1"
WIN_MINION2="${VM_PREFIX}-win2"
ANSIBLE_MASTER="${VM_PREFIX}-ansible"

crudini --set k8s-cluster.ini linux server-names "${LINUX_MASTER},${LINUX_MINION}"
crudini --set k8s-cluster.ini linux user-data "./linux-user-data"
crudini --set k8s-cluster.ini linux image "${LINUX_IMAGE}"

crudini --set k8s-cluster.ini windows server-names "${WIN_MINION1},${WIN_MINION2}"
crudini --set k8s-cluster.ini windows user-data "./windows-user-data"
crudini --set k8s-cluster.ini windows image "${WINDOWS_IMAGE}"

crudini --set k8s-cluster.ini ansible server-name "${ANSIBLE_MASTER}"
crudini --set k8s-cluster.ini ansible user-data "./ansible-user-data"
crudini --set k8s-cluster.ini ansible image "${LINUX_IMAGE}"

crudini --set k8s-cluster.ini network internal ${INTERNAL_OPENSTACK_NETWORK}
crudini --set k8s-cluster.ini network external ${EXTERNAL_OPENSTACK_NETWORK}

crudini --set k8s-cluster.ini report file-path "./report.ini"

crudini --set k8s-cluster.ini keys private ${SSH_KEY}
crudini --set k8s-cluster.ini keys name ${SSH_KEY_NAME}

crudini --set k8s-cluster.ini kubernetes noremote kubernetes
crudini --set k8s-cluster.ini kubernetes commit "v1.12.3"


popd

sleep 10000
