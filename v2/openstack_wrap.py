import utils
import json
import re
import time
from threading import Timer

def server_create(name, flavor, imageID, networkID, keyName, userData):
    cmd = ("openstack server create --flavor=%(flavor)s --image=%(image)s --nic net-id=%(network)s "
           "--key-name=%(keyName)s --user-data=%(userData)s %(name)s --wait -f json") % {"flavor": flavor,
                                                                                 "image": imageID,
                                                                                 "network": networkID,
                                                                                 "keyName": keyName,
                                                                                 "userData": userData,
                                                                                 "name": name }
    cmd = cmd.split()
    out, err , ret = utils.run_cmd(cmd, stdout=True, stderr=True)
    if ret == 0:
        return json.loads(out)
    else:
        raise Exception("Failed to create server: %s with error: %s" % (name, err))


def server_delete(server):
    # server = id or name of server
    # Should check it exists before trying to delete
    cmd = ("openstack server delete %s --wait" % server)
    cmd = cmd.split()
    _, err, ret = utils.run_cmd(cmd, stderr=True)
    if ret != 0:
        if "No server with a name or ID" in err:
            return
        raise Exception("Failed to delete server: %s with error: %s" % (server, err))

def floating_ip_list(used=False):
    if used:
        status="ACTIVE"
    else:
        status="DOWN"
    cmd = ["openstack", "floating", "ip", "list", "--sort-column=\"Floating IP Address\"", "--status=%s" % status, "-f", "json"] 
    out, err, ret = utils.run_cmd(cmd, stderr=True, stdout=True)
    if ret == 0:
        return json.loads(out)
    else:
        raise Exception("Failed to list floating ips with error %s." % err)

def get_floating_ip(floating_ip_obj):
    return floating_ip_obj["Floating IP Address"]

def get_floating_ip_fixed_address(floating_ip_obj):
    return floating_ip_obj["Fixed IP Address"]

def get_floating_ip_id(floating_ip_obj):
    return floating_ip_obj["ID"]

def floating_ip_create(external_network_id):
    cmd = "openstack floating ip create %s -f json" % external_network_id
    cmd = cmd.split()
    out, err, ret = utils.run_cmd(cmd, stdout=True, stderr=True)
    if ret == 0:
        return json.loads(out)
    else:
        raise Exception("Failed to list create floating ip with error %s" % err)

def server_add_floating_ip(server, ip):
    # server = Name or ID of server
    # ip = IP only
    cmd = ("openstack server add floating ip %s %s") % (server, ip)
    cmd = cmd.split()

    _, err, ret = utils.run_cmd(cmd, stderr=True)
    if ret != 0:
        raise Exception("Failed to add floating ip %s for server %s with error %s" % (ip, server, err))


def server_remove_floating_ip(server, ip):
    cmd = ("openstack server remove floating ip %s %s") % (server, ip)
    cmd = cmd.split()

    _, err, ret = utils.run_cmd(cmd, stderr=True)
    if ret != 0:
        raise Exception("Failed to remove floating ip %s for server %s with error %s" % (ip, server, err))

def server_get_password(server, ssh_key):

    cmd = ("nova get-password %s %s" % (server, ssh_key))
    cmd = cmd.split()
    tries = 60 # retrying for 600 seconds / 10 second sleep = 60 times. Windows machiens take a long time to get passwd 

    passwd = ""
    while passwd == "" and tries != 0:
        tries = tries - 1
        time.sleep(10)
        out, err, ret = utils.run_cmd(cmd, stdout=True, stderr=True)
        if ret == 0:
            passwd=out.strip()
        else:
            raise Exception("Failed to get passwod for server %s with error %s" % (server, err))
    if tries == 0:
        raise Exception("Timed out waiting for nova password.")
    return passwd

