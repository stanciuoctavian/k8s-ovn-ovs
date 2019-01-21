import configargparse
import logging
import utils
import tempfile
import os
import time
import subprocess

p = configargparse.get_argument_parser()
logging.basicConfig(level=logging.DEBUG, format='%(levelname)s %(asctime)s %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p')

JOB_REPO_CLONE_DST = os.path.join(tempfile.gettempdir(), "k8s-ovn-ovs")
DEFAULT_JOB_CONFIG_PATH = os.path.join(tempfile.gettempdir(), "job_config.txt")

def parse_args():

    def str2bool(v):
        if v.lower() == "true":
            return True
        elif v.lower() == "false":
            return False
        else:
            raise configargparse.ArgumentTypeError('Boolean value expected')

    p.add('--job-config', help='Configuration for job to be ran. URL or file.')
    p.add('--job-repo', default="http://github.com/adelina-t/k8s-ovn-ovs", help='Respository for job runner.')
    p.add('--job-branch', default="master", help='Branch for job runner.')
    p.add('job_args', nargs=configargparse.REMAINDER)

    opts = p.parse_known_args()

    return opts

def get_job_config_file(job_config):
    if job_config == None:
        return None
    if os.path.isfile(job_config):
        return os.path.abspath(job_config)
    utils.download_file(job_config, DEFAULT_JOB_CONFIG_PATH)
    return DEFAULT_JOB_CONFIG_PATH

def get_cluster_name():
    # The cluster name is composed of the first 8 chars of the prowjob in case it exists
    return os.getenv("PROW_JOB_ID","0000-0000-0000-0000")[:7]    

def main():
    opts = parse_args()[0]
    time.sleep(100) # Give the container time to get DNS
    logging.info(opts.job_config)
    logging.info("Clonning job repo: %s on branch %s." % (opts.job_repo, opts.job_branch))
    utils.clone_repo(opts.job_repo, opts.job_branch, JOB_REPO_CLONE_DST)
    job_config_file = get_job_config_file(opts.job_config)
    logging.info("Using job config file: %s" % job_config_file)
    cluster_name=get_cluster_name()

    cmd = ["python", "civ2.py"] + opts.job_args[1:]
    cmd.append("--configfile=%s" % job_config_file)
    cmd.append("--cluster-name=%s" % cluster_name)

    subprocess.call(cmd, cwd=os.path.join(JOB_REPO_CLONE_DST,"v2"))
    
if __name__ == "__main__":
    main()