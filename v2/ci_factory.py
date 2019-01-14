import ci
import ovn_ovs


CI_MAP = {
    "ovn-ovs": ovn_ovs.OVN_OVS_CI
}

def get_ci(name):
    ci_obj = CI_MAP.get(name, ci.CI)
    return ci_obj()