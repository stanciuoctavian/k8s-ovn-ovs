#!/bin/bash

# This script is responsable for creating the config.ini file with job specific params and pass it on to the
# ./create-cluster.sh script

set -e

CREATE_CLUSTER_REPO="http://github.com/e2e-win/k8s-ovn-ovs"

DEFAULT_PROW_JOB_ID="00-00"
DEFAULT_BUILD_ID="0000"
DEFAULT_NODE_NAME="k8s-ovn-lin1"
DEFAULT_RESULT="FAILURE"

# test vars

GINKGO_PARALLEL=${GINKGO_PARALLEL:-1}

# setup log & artifacts collecting

if [[ -z "${GCLOUD_SERVICE_ACCOUNT}" ]]; then
  echo "GCLOUD_SERVICE_ACCOUNT not set. Exiting."
  exit 1
fi

if [[ -z "${GCLOUD_UPLOAD_BUCKET}" ]]; then
  echo "GCLOUD_UPLOAD_BUCKET not set. Exiting."
  exit 1
fi

function run_cmd() {
"$@"
return=$?
if [[ ! $return -eq 0 ]]
then
echo "Command [ $@ ] FAILED with exit status $return . "
fi
}


function gcloud_login() {

	echo "Logging in to gcloud"
	run_cmd gcloud auth activate-service-account --key-file=${GCLOUD_SERVICE_ACCOUNT}

}

function set_job_results_paths() {

	REMOTE_BUILD_LOGS_FOLDER="${GCLOUD_UPLOAD_BUCKET}/${JOB_NAME}/${BUILD_ID}"
	REMOTE_ARTIFACTS="${REMOTE_BUILD_LOGS_FOLDER}/artifacts"
	REMOTE_BUILD_LOG="${REMOTE_BUILD_LOGS_FOLDER}/build-log.txt"
	REMOTE_FINISHED="${REMOTE_BUILD_LOGS_FOLDER}/finished.json"
	REMOTE_STARTED="${REMOTE_BUILD_LOGS_FOLDER}/started.json"
        REMOET_RESULTS_CACHE="${GCLOUD_UPLOAD_BUCKET}/{JOB_NAME}/jobResultsCache.json"
        REMOTE_LATEST="${GCLOUD_UPLOAD_BUCKET}/{JOB_NAME}/latest-build.txt"

	# Set local paths

	BASE=$HOME/results
	ARTIFACTS="${BASE}/artifacts"
	mkdir -p ${ARTIFACTS}

        BUILD_LOG="${BASE}/build-log.txt"
        FINISHED="${BASE}/finished.json"
        STARTED="${BASE}/started.json"
        RESULTS_CACHE="${BASE}/jobResultsCache.json"
        LATEST="${BASE}/latest-build.txt"

}

function gcloud_upload_folder() {
	local src=$1
        local dst=$2

	echo "Uploading $src to $dst ."
	run_cmd gsutil -q cp -r $src/* $dst
}

function get_time() {
	date +%s
}

function start() {

	local timestamp=`get_time`
	local node_name=$DEFAULT_NODE_NAME

	echo "Generating started.json. Start time: $timestamp"

	jq -n --arg "timestamp" $timestamp --arg "node" $node_name -f /started_template.jq > ${STARTED}

}

function finish() {

	local timestamp=`get_time`
        local result=${RESULT:-DEFAULT_RESULT}

	echo "Generating finished.json. Finish time: $timestamp"

        jq -n --arg "timestamp" $timestamp --arg "result" $result -f /finished_template.jq > ${FINISHED}

}

set_job_results_paths

exec &> >(tee -a ${BUILD_LOG})

# Attempt gcloud login
gcloud_login

mkdir -p /root/.ssh
touch /root/.ssh/known_hosts

function clone-repo() {

	REPO=$1
	BRANCH=${2:-"master"}

	echo "Cloning into repo ${REPO} , branhc ${BRANCH}"

	git clone -b ${BRANCH} ${REPO}

}

function upload_results() {

	echo "Uploading results to $REMOTE_BUILD_LOGS_FOLDER"

	finish
	gcloud_upload_folder ${BASE} ${REMOTE_BUILD_LOGS_FOLDER}
}

trap upload_results EXIT

# Create started.json
start


clone-repo $CREATE_CLUSTER_REPO
pushd k8s-ovn-ovs/openstack-scripts

VM_PREFIX=`echo "${PROW_JOB_ID:-DEFAULT_PROW_JOB_ID}" | cut -c1-8`

LINUX_MASTER="${VM_PREFIX}-master"
LINUX_MINION="${VM_PREFIX}-lin-minion"
WIN_MINION1="${VM_PREFIX}-win1"
WIN_MINION2="${VM_PREFIX}-win2"
ANSIBLE_MASTER="${VM_PREFIX}-ansible"

echo "Setting k8s-cluster.ini with job parameters."
echo "Cluster vm prefix: ${VM_PREFIX}"

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
crudini --set k8s-cluster.ini kubernetes commit "master"

echo "Deploying cluster using k8s-cluster.ini."

export GINKGO_PARALLEL=${GINKGO_PARALLEL}

sleep 10000

./create-cluster.sh --config k8s-cluster.ini --up --down --test --admin-openrc=$ADMIN_OPENRC

if [[ ! ${PIPESTATUS[0]} -eq 0 ]]; then
	RESULT="FAILURE"
else
	RESULT="SUCCESS"
fi

upload_results

popd
