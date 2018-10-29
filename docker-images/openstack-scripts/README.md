# Openstack scripts image

This image contains all dependencies to run the openstack scripts and deploy, and test a k8s cluster

It needs a config and the admin-openrc to connect to the openstack API

### Configuration

All configuration is done through volumes
```bash
config.ini      -> /etc/k8s-ovn-ovs/config.ini
admin-openrc.sh -> /etc/k8s-ovn-ovs/admin-openrc.sh 
```

### Example usage

```bash
docker run --name=openstack-scripts -d -v "$(pwd)"/config.ini:/etc/k8s-ovn-ovs/config.ini:ro -v $HOME/admin-openrc.sh:/etc/k8s-ovn-ovs/admin-openrc.sh:ro -v "$(pwd)/id_rsa":/etc/k8s-ovn-ovs/id_rsa:ro papagalu/k8s-ovn-ovs --config --ansible --admin-openrc
```
