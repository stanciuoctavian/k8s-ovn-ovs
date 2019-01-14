
import configargparse
import ci_factory

p = configargparse.get_argument_parser()

def parse_args():

    def str2bool(v):
        if v.lower() == "true":
            return True
        elif v.lower() == "false":
            return False
        else:
            raise configargparse.ArgumentTypeError('Boolean value expected')

    p.add('-c', '--configfile', is_config_file=True, help='Config file path.')
    p.add('--up', type=str2bool, default=False, help='Deploy test cluster.')
    p.add('--down', type=str2bool, default=False, help='Destroy cluster on finish.')
    p.add('--test', type=str2bool, default=False, help='Run tests.')
    p.add('--admin-openrc', default=False, help='Openrc file for OpenStack cluster')
    p.add('--log-path', help='Path to place all artifacts')
    p.add('--ci', required=True, help="OVN-OVS, Flannel")
    
    opts = p.parse_known_args()

    return opts

     
def main():
    try:
        opts = parse_args()[0]
        ci = ci_factory.get_ci(opts.ci)

        if opts.up == True:
            if opts.down == True:
                ci.down()
            ci.up()
        if opts.test == True:
            ci.test()
        if opts.down == True:
            ci.down()
    except Exception as e:
        raise e
    finally:
        if opts.down == True:
            ci.down()    

if __name__ == "__main__":
    main()
