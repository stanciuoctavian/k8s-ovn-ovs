
import configargparse
import ci_factory
import log
import utils
import sys

p = configargparse.get_argument_parser()

logging = log.getLogger(__name__)

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
    p.add('--build', type=str2bool, default=True, help='Build k8s binaries.')
    p.add('--test', type=str2bool, default=False, help='Run tests.')
    p.add('--admin-openrc', default=False, help='Openrc file for OpenStack cluster')
    p.add('--log-path', default="/tmp/civ2_logs", help='Path to place all artifacts')
    p.add('--ci', help="OVN-OVS, Flannel")
    p.add('--cluster-name', help="Name of cluster.")
    p.add('--k8s-repo', default="http://github.com/kubernetes/kubernetes")
    p.add('--k8s-branch', default="master")
    p.add('--hold', type=str2bool, default=False, help='Useful for debugging while running in containerd. \
                                                        Sleeps the process after setting the env for testing so user can manually exec from container.')
    
    opts = p.parse_known_args()

    return opts

     
def main():
    try:
        opts = parse_args()[0]
        logging.info("Starting with CI: %s" % opts.ci)
        logging.info("Creating log dir: %s." % opts.log_path)
        utils.mkdir_p(opts.log_path)
        ci = ci_factory.get_ci(opts.ci)
        success = 0

        if opts.build:
            ci.build()

        if opts.up == True:
            if opts.down == True:
                ci.down()
            ci.up()
        if opts.test == True:
            success = ci.test()
        if opts.down == True:
            ci.down()
	if success is None:
            raise Exception
	sys.exit(0)
    except Exception as e:
        logging.error(e)
        if opts.down == True:
            ci.down() 
	sys.exit(1)

if __name__ == "__main__":
    main()
