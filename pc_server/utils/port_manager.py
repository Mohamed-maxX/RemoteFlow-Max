"""
RemoteFlow Max - Single Instance & Port Management Utility
Prevents [WinError 10048] socket conflicts by detecting and cleanly terminating
any stale background instances or orphaned listeners on ports 5055, 5056, 5057, 5058.
"""

import os
import sys
import time
import logging

logger = logging.getLogger("RemoteFlow.PortManager")

def free_conflicting_ports(ports=(5055, 5056, 5057, 5058), max_wait_sec=2.5) -> int:
    """
    Scans for any processes holding the target ports and terminates them cleanly.
    Excludes the current process and its parent/child hierarchy (critical for PyInstaller onefile).
    Returns the count of terminated conflicting processes.
    """
    current_pid = os.getpid()
    terminated_count = 0

    try:
        import psutil
    except ImportError:
        logger.warning("psutil not available; port conflict auto-resolution skipped.")
        return 0

    # Build set of self + ancestors/descendants to never kill
    protected_pids = {current_pid}
    try:
        current_proc = psutil.Process(current_pid)
        for parent in current_proc.parents():
            protected_pids.add(parent.pid)
        for child in current_proc.children(recursive=True):
            protected_pids.add(child.pid)
    except Exception:
        if hasattr(os, 'getppid'):
            protected_pids.add(os.getppid())

    # 1. Terminate conflicting processes specifically listening on our ports
    for conn in psutil.net_connections(kind='inet'):
        try:
            if conn.laddr and conn.laddr.port in ports and conn.pid:
                pid = conn.pid
                if pid not in protected_pids:
                    try:
                        p = psutil.Process(pid)
                        p_name = p.name()
                        logger.info(f"Port {conn.laddr.port} occupied by {p_name} (PID: {pid}). Freeing port...")
                        p.terminate()
                        try:
                            p.wait(timeout=max_wait_sec)
                        except psutil.TimeoutExpired:
                            p.kill()
                        terminated_count += 1
                        protected_pids.add(pid) # avoid double terminating
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        pass
        except Exception:
            pass

    # 2. Terminate any disconnected stale RemoteFlowMax.exe instances from previous crashes
    for proc in psutil.process_iter(['pid', 'name']):
        try:
            pid = proc.info['pid']
            pname = (proc.info['name'] or '').lower()
            if pid not in protected_pids and pname in ("remoteflowmax.exe", "remoteflow_server.exe"):
                logger.info(f"Terminating orphaned stale instance {pname} (PID: {pid})...")
                proc.terminate()
                terminated_count += 1
                protected_pids.add(pid)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass

    if terminated_count > 0:
        logger.info(f"Successfully released {terminated_count} conflicting processes. Allowing socket unbind buffer...")
        time.sleep(0.4)

    return terminated_count
