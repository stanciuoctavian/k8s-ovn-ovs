import subprocess
import os
from threading import Timer


class CmdTimeoutExceededException(Exception):
    pass

def run_cmd(cmd, timeout=50000, env=None, stdout=False, stderr=False):

    def kill_proc_timout(proc):
        proc.kill()
        raise CmdTimeoutExceededException("Timeout of %s exceeded for cmd %s" % (timeout, cmd))

    FNULL = open(os.devnull, "w")
    f_stderr = FNULL
    f_stdout = FNULL
    if stdout == True:
        f_stdout = subprocess.PIPE
    if stderr == True:
        f_stderr = subprocess.PIPE
    proc = subprocess.Popen(cmd, env=env, stdout=f_stdout, stderr=f_stderr)
    timer=Timer(timeout, kill_proc_timout, [proc])
    try:
        timer.start()
        stdout, stderr = proc.communicate()
        return stdout, stderr, proc.returncode
    finally:
        timer.cancel()
    