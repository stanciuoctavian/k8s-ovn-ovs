import ovn_ovs

class Flannel_CI(ovn_ovs.OVN_OVS_CI):
    def __init__(self):
        super(Flannel_CI, self).__init__()
        print dir(self)