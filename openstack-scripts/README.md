# Openstack Scripts

This folder contains scripts that spawn a cluster of k8s.

The workflow is the following:
  - spawn VMs
  - configure ansible
  - deploy k8s
  
## How to

The main script is create-cluster.sh and it supports the following parameters:

```bash
--config   # config file to be used
--clean    # will delete the cluster if it's already up and create a new one
--down     # will just delete the current cluster
--ansible  # also spawns an ansible-machine and configures it
```

Example usage:

```bash
# just spawn the VMs
./create-cluster.sh --config k8s-cluster.ini

# clean the previous VMs and spawn new ones
./create-cluster.sh --config k8s-cluster.ini --clean

# delete cluster
./create-cluster.sh --config k8s-cluster.ini --down

# create cluster with ansible node too
./create-cluster.sh --config k8s-cluster.ini --ansible

# delete cluster and also the ansible node
./create-cluster.sh --config k8s-cluster.ini --down --ansible

# delete previous cluster and spawn a new one with ansible master
./create-cluster.sh --config k8s-cluster.ini --ansible --clean
```

The config file:

```ini
[linux]
server-names = linux1,linux2 # linux servers, they should be delimited with "," char and contain no spaces
user-data =                  # path to the linux user data
flavor =                     # openstack flavor to use for linux minions
image = xenial-20180831      # openstack image to use for linux minions

[windows]
server-names =               # windows servers, they should be delimited with "," char and contain no spaces
user-data =                  # path to the windows user data
flavor =                     # openstack flavor to use for windows minions
image =                      # openstack image to use for windows minions

[ansible]
server-name = ansible-master # server name for the ansible master/deployer
user-data =                  # path to the ansible master user data

[keys]
private =                    # path to the private key used in openstack
name =                       # name of the key in openstack (must be the public pair of the private one)

[network]
internal =                   # openstack internal network
external =                   # openstack external network

[report]
file-path =                  # path to report.ini, it's used to report nodes to the ansible master machine
```
k8s-cluster.ini is the config file used right now, please use it as an example.

### What to pay attention to:

Don't give servers names longer than 15 chars since on Windows by default 15 is the limit, and k8s also has a limit.

It is advised tp run the script in screen, since it takes a while to deploy the k8s cluster.
