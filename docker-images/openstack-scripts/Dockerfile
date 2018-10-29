FROM alpine

RUN apk add --no-cache --update --virtual build-deps git py-pip build-base python-dev linux-headers libffi-dev openssl-dev && \
    pip install python-openstackclient && \
    pip install python-novaclient && \
    git clone https://github.com/e2e-win/k8s-ovn-ovs && \
    cd k8s-ovn-ovs && \
    git checkout dev && \
    cd ..  && \
    apk del build-deps

RUN apk add --no-cache bash py-pip && \
    pip install crudini

ENTRYPOINT ["./k8s-ovn-ovs/openstack-scripts/create-cluster.sh"]
