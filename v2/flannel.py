import ovn_ovs
import time

class Flannel_CI(ovn_ovs.OVN_OVS_CI):
    def __init__(self):
        super(Flannel_CI, self).__init__()
    
    def _prepare_ansible(self):
        time.sleep(10000000)

