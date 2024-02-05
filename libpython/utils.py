#!/usr/env/bin python3

import os
import signal
import psutil
import getpass

def kill_proc_tree(pid, sig=signal.SIGTERM, include_parent=True,
                   timeout=None, on_terminate=None):
    """Kill a process tree (including grandchildren) with signal
    "sig" and return a (gone, still_alive) tuple.
    "on_terminate", if specified, is a callback function which is
    called as soon as a child terminates.
    """
    assert pid != os.getpid(), "won't kill myself"
    parent = psutil.Process(pid)
    children = parent.children(recursive=True)
    if include_parent:
        children.append(parent)
    for p in children:
        try:
            p.send_signal(sig)
        except psutil.NoSuchProcess:
            pass
    gone, alive = psutil.wait_procs(children, timeout=timeout,
                                    callback=on_terminate)
    for p in alive:
        p.kill()

def kill_named_proc_tree(name):
    for p in psutil.process_iter(['name', 'username', 'cmdline']):
        if p.info['username'] == getpass.getuser(): 
            try:
                if p.info["cmdline"][1].endswith(name):
                    print(f"Killing {p.pid} {p.info}")
                    kill_proc_tree(p.pid)
            except:
                pass

def kill_ycsb_proc_tree(name="ycsb.sh"):
    kill_named_proc_tree(name=name)

def kill_arcion_proc_tree(name="replicant"):
    kill_named_proc_tree(name=name)