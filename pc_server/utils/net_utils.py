"""
RemoteFlow Max - Network Utilities
Detects host IP addresses across Wi-Fi and Ethernet interfaces.
"""

import socket
import logging

logger = logging.getLogger("RemoteFlow.NetUtils")

def get_primary_local_ip() -> str:
    """
    Determines the most likely LAN IP used to communicate with the local network
    by opening a dummy UDP socket towards an external gateway address.
    Does not actually send any network packet.
    """
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0.1)
        # 10.255.255.255 or public DNS
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        if ip and not ip.startswith("127."):
            return ip
    except Exception:
        pass

    # Fallback to gethostbyname
    try:
        hostname = socket.gethostname()
        ip = socket.gethostbyname(hostname)
        if ip and not ip.startswith("127."):
            return ip
    except Exception:
        pass

    return "127.0.0.1"

def get_all_local_ips() -> list[str]:
    """Returns a list of all local IPv4 addresses."""
    ips = set()
    primary = get_primary_local_ip()
    if primary != "127.0.0.1":
        ips.add(primary)

    try:
        hostname = socket.gethostname()
        for info in socket.getaddrinfo(hostname, None, socket.AF_INET):
            ip = info[4][0]
            if not ip.startswith("127."):
                ips.add(ip)
    except Exception:
        pass

    return list(ips) if ips else ["127.0.0.1"]
