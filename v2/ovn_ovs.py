import ci
import configargparse
import openstack_wrap as openstack

p = configargparse.get_argument_parser()

p.add("--linuxVMs", action="append", help="Name for linux VMS. List.")
p.add("--linuxUserData", help="Linux VMS user-data.")
p.add("--linuxFlavor", help="Linux VM flavor.")
p.add("--linuxImageID", help="ImageID for linux VMs.")

p.add("--windowsVMs", action="append", help="Name for Windows VMs. List.")
p.add("--windowsUserData", help="Windows VMS user-data.")
p.add("--windowsFlavor", help="Windows VM flavor.")
p.add("--windowsImageID", help="ImageID for windows VMs.")

p.add("--keyName", help="Openstack SSH key name")
p.add("--keyFile", help="Openstack SSH private key")

p.add("--internalNet", help="Internal Network for VMs")
p.add("--externalNet", help="External Network for floating ips")

class OVN_OVS_CI(ci.CI):

    def __init__(self):
        self.opts = p.parse_known_args()[0]
        self.cluster = {}

    def _add_linux_vm(self, vm_obj):
        if self.cluster.get("linuxVMs") == None:
            self.cluster["linuxVMs"] = []
        self.cluster["linuxVMs"].append(vm_obj)

    def _add_windows_vm(self, vm_obj):
        if self.cluster.get("windowsVMs") == None:
            self.cluster["windowsVMs"] = []
        self.cluster["windowsVMs"].append(vm_obj)

    def _get_windows_vms(self):
        return self.cluster.get("windowsVMs")

    def _create_vms(self):
        vmPrefix = self.opts.cluster_name
        for vm in self.opts.linuxVMs:
            openstack_vm = openstack.server_create("%s-%s" % (vmPrefix, vm), self.opts.linuxFlavor, self.opts.linuxImageID, 
                                                   self.opts.internalNet, self.opts.keyName, self.opts.linuxUserData)
            fip = openstack.get_floating_ip(openstack.floating_ip_list()[0])
            openstack.server_add_floating_ip(openstack_vm['name'], fip)
            self._add_linux_vm(openstack_vm)
        for vm in self.opts.windowsVMs:
            openstack_vm = openstack.server_create("%s-%s" % (vmPrefix, vm), self.opts.windowsFlavor, self.opts.windowsImageID, 
                                                   self.opts.internalNet, self.opts.keyName, self.opts.windowsUserData)
            fip = openstack.get_floating_ip(openstack.floating_ip_list()[0])
            openstack.server_add_floating_ip(openstack_vm['name'], fip)
            self._add_windows_vm(openstack_vm)
        print self._get_windows_vms()

    def _wait_for_windows_machines(self):
        for vm in self._get_windows_vms():
            openstack.server_get_password(vm['name'], self.opts.keyName)

    def _prepare_env(self):
        self._create_vms()
        self._wait_for_windows_machines()

    def _destroy_cluster(self):
        vmPrefix = self.opts.cluster_name
        for vm in self.opts.linuxVMs:
            openstack.server_delete("%s-%s" % (vmPrefix, vm))
        for vm in self.opts.windowsVMs:
            openstack.server_delete("%s-%s" % (vmPrefix, vm))

    def up(self):
        try:
            self._prepare_env()
        except Exception as e:
            raise e
    
    def down(self):
        try:
            self._destroy_cluster()
        except Exception as e:
            raise e