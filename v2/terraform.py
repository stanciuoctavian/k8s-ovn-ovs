import configargparse
import deployer
import log
import utils
import os
import subprocess
import json
from azure.common.credentials import ServicePrincipalCredentials
from azure.mgmt.resource import ResourceManagementClient

p = configargparse.get_argument_parser()

p.add("--location", default="eastus", help="Resource group location.")
p.add("--rg_name", help="resource group name.")
p.add("--master-vm-name", help="Name of master vm.")
p.add("--master-vm-size", default="Standard_D2s_v3", help="Size of master vm")

p.add("--win-minion-count", type=int ,default=2, help="Number of windows minions for the deployment.")
p.add("--win-minion-name-prefix", default="winvm", help="Prefix for win minion vm names.")
p.add("--win-minion-size", default="Standard_D2s_v3", help="Size of minion vm")

p.add("--terraform-config")
p.add("--ssh-public-key-path", default=os.path.join(os.path.join(os.getenv("HOME"), ".ssh", "id_rsa.pub")) )
p.add("--ssh-private-key-path", default=os.path.join(os.path.join(os.getenv("HOME"), ".ssh", "id_rsa")))

class TerraformProvisioner(deployer.NoopDeployer):

    def __init__(self):
        self.opts = p.parse_known_args()[0]
        self.cluster = self._generate_cluster()
        self.terraform_config_url = self.opts.terraform_config

        self.terraform_root = "/tmp/terraform_root"
        self.terraform_config_path = os.path.join(self.terraform_root, "terraform.tf")
        self.terraform_vars_file = os.path.join(self.terraform_root, "terraform.tfvars")

        self.logging = log.getLogger(__name__)

        self._generate_cluster()
        self._create_terraform_root()

    def _generate_cluster(self):
        cluster = {}

        cluster["location"] = self.opts.location
        cluster["resource_group"] = self.opts.rg_name
        cluster["master_vm"] = dict(vm_name=self.opts.master_vm_name, vm_size=self.opts.master_vm_size, public_ip=None)
        cluster["win_vms"] = dict(win_vm_name_prefix=self.opts.win_minion_name_prefix,
                                  win_vm_count=self.opts.win_minion_count,
                                  win_vm_size=self.opts.win_minion_size,
                                  vms=[])
        for index in range(cluster["win_vms"]["win_vm_count"]):
            vm_name = self.opts.win_minion_name_prefix + str(index)
            cluster["win_vms"]["vms"].append(dict(vm_name=vm_name, public_ip=None))
    
        return cluster

    def get_cluster_location(self):
        return self.cluster["location"]
    
    def get_cluster_rg_name(self):
        return self.cluster["resource_group"]

    def get_cluster_master_vm_name(self):
        return self.cluster["master_vm"]["vm_name"]
    
    def get_cluster_master_public_ip(self):
        return self.cluster["master_vm"]["public_ip"]

    def _set_cluster_master_vm_public_ip(self, master_public_ip):
        self.cluster["master_vm"]["public_ip"] = master_public_ip
    
    def _set_cluster_win_min_public_ip(self, vm_name, vm_public_ip):
        for vm in self.cluster["win_vms"]["vms"]:
            if vm["vm_name"] == vm_name:
                vm["public_ip"] = vm_public_ip

    def get_cluster_master_vm_size(self):
        return self.cluster["master_vm"]["vm_size"]
    
    def get_cluster_master_vm(self):
        return self.cluster["master_vm"]

    def get_cluster_win_minion_vm_prefix(self):
        return self.cluster["win_vms"]["win_vm_name_prefix"]

    def get_cluster_win_minion_vm_count(self):
        return self.cluster["win_vms"]["win_vm_count"]
    
    def get_cluster_win_minion_vm_size(self):
        return self.cluster["win_vms"]["win_vm_size"]

    def get_cluster_win_minion_vms(self):
        return self.cluster["win_vms"]["vms"]
    
    def get_cluster_win_minion_vms_names(self):
        return [vm["vm_name"] for vm in self.get_cluster_win_minion_vms()]
    
    def get_all_vms(self):
        vms = []
        vms.append(self.get_cluster_master_vm())
        vms.extend(self.get_cluster_win_minion_vms)

        return vms

    def _create_terraform_root(self):
        utils.rm_dir(self.terraform_root)
        utils.mkdir_p(self.terraform_root)

    def _get_terraform_config(self):
        self.logging.info("Downloading terraform config.")
        utils.download_file(self.terraform_config_url, self.terraform_config_path)

    def _get_ssh_public_key(self, key_file):
        if not os.path.exists(key_file):
            msg = ("Unable to find ssh key %s. No such path exists." % key_file)
            self.logging.error(msg)
            raise Exception(msg)
        
        with open(key_file, "r") as f:
            pub_key = f.read().strip()

        return pub_key

    def get_win_vm_password(self, vm_name):
        return "Passw0rd1234"

    def get_win_vm_username(self, vm_name):
        return "azureuser"

    def get_master_username(self):
        return "azureuser"

    def _create_terraform_vars_file(self):
        self.logging.info("Creating terraform vars file.")
        out_format = '%s = "%s"\n'
        ssh_public_key = self._get_ssh_public_key(self.opts.ssh_public_key_path)
        with open(self.terraform_vars_file, "w") as f:
            f.write(out_format % ("location", self.get_cluster_location()))
            f.write(out_format % ("rg_name", self.get_cluster_rg_name()))
            f.write(out_format % ("master_vm_name", self.get_cluster_master_vm_name()))
            f.write(out_format % ("master_vm_size", self.get_cluster_master_vm_size()))
            f.write(out_format % ("win_minion_count", self.get_cluster_win_minion_vm_count()))
            f.write(out_format % ("win_minion_vm_size", self.get_cluster_win_minion_vm_size()))
            f.write(out_format % ("win_minion_vm_name_prefix", self.get_cluster_win_minion_vm_prefix()))
            f.write(out_format % ("ssh_key_data", ssh_public_key))

    def _get_terraform_vars_azure(self):
        cmd = []
        msg = "Env var %s not set."
        env_vars = ["AZURE_SUB_ID", "AZURE_CLIENT_ID", "AZURE_CLIENT_SECRET", "AZURE_TENANT_ID"]
        terraform_vars = ["azure_sub_id", "azure_client_id", "azure_client_secret", "azure_tenant_id"]

        for terraform_var, env_var in zip(terraform_vars, env_vars):
            if not os.getenv(env_var):
                self.logging.error(msg % env_var)
                raise Exception(msg % env_var)
            cmd.append("-var")
            var = ("'%s=%s'" % (terraform_var, os.getenv(env_var).strip()))
            cmd.append(var)
        
        return cmd

    def _get_terraform_apply_cmd(self):
        cmd = ["terraform", "apply", "-auto-approve"] 

        cmd.extend(self._get_terraform_vars_azure())
        cmd.append(".")

        return cmd

    def _deploy_cluster(self):
        self.logging.info("Deploying cluster")

        self.logging.info("Init terraform.")
        cmd = ["terraform","init"]
        
        _, err, ret = utils.run_cmd(cmd, stderr=True, cwd=self.terraform_root)
        if ret != 0:
            msg = "Failed to init terraform with error: %s" % err
            self.logging.error(msg)
            raise Exception(msg)
        
        cmd = self._get_terraform_apply_cmd()
        out, err, ret = utils.run_cmd(cmd, stdout=True, stderr=True, cwd=self.terraform_root, shell=True, sensitive=True)
        if ret != 0:
            msg = "Failed to apply terraform config with error: %s" % err
            self.logging.error(msg)
            raise Exception(msg)

        cmd = ["terraform", "output", "-json"]
        out, err, ret = utils.run_cmd(cmd, stdout=True, stderr=True, cwd=self.terraform_root)

        return json.loads(out)

    def _parse_terraform_output(self, output):
        master_ip = output["master"]["value"][self.get_cluster_master_vm_name()]
        self._set_cluster_master_vm_public_ip(master_ip)
        for vm_name, vm_pub_ip in output["winMinions"]["value"].items():
            self._set_cluster_win_min_public_ip(vm_name, vm_pub_ip)
        
        print json.dumps(self.cluster)

    def _populate_hosts_file(self):
        with open("/etc/hosts", "a") as f:
            vm_name = self.get_cluster_master_vm_name()
            vm_name = vm_name + " kubernetes"
            vm_public_ip = self.get_cluster_master_public_ip()
            hosts_entry=("%s %s\n" % (vm_public_ip, vm_name))
            self.logging.info("Adding entry %s to hosts file." % hosts_entry)
            f.write(hosts_entry)

            for vm in self.get_cluster_win_minion_vms():
                vm_name = vm["vm_name"]
                vm_public_ip = vm["public_ip"]
                if vm_name.find("master") > 0:
                    vm_name = vm_name + " kubernetes"
                hosts_entry=("%s %s\n" % (vm_public_ip, vm_name))
                self.logging.info("Adding entry %s to hosts file." % hosts_entry)
                f.write(hosts_entry)

    def up(self):
        self.logging.info("Terraform up.")
#        self._get_terraform_config()
#        self._create_terraform_vars_file()
#        terraform_output = self._deploy_cluster()
#        self._parse_terraform_output(terraform_output)
#        self._populate_hosts_file()

    def down(self):
        # Unfortunately, terraform destroy is not working properly
        # Destroy will be handled via SDK calls
        self.logging.info("Az destroy rgdel")

        try:
            credentials = ServicePrincipalCredentials(
                client_id=os.environ['AZURE_CLIENT_ID'].strip(),
                secret=os.environ['AZURE_CLIENT_SECRET'].strip(),
                tenant=os.environ['AZURE_TENANT_ID'].strip()
            )
            subscription_id = os.environ.get(
                'AZURE_SUB_ID',
                '11111111-1111-1111-1111-111111111111'
            ).strip()
            client = ResourceManagementClient(credentials, subscription_id)
            delete_async_operation = client.resource_groups.delete(self.opts.rg_name)
            delete_async_operation.wait()
        except Exception as e:
            # Should find specific exception for when RG is not found
            self.logging.error("Failed to destroy rgdel with error: %s", e)

