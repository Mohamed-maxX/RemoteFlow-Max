"""
RemoteFlow Max - Terminal QR Code & Pairing Utility
Generates ASCII QR code for zero-touch pairing with the mobile client.
"""

import json
import logging
import qrcode
from io import StringIO

logger = logging.getLogger("RemoteFlow.QR")

def generate_pairing_payload(ip: str, ws_port: int, udp_port: int, server_name: str) -> str:
    """Generates standard JSON pairing connection string."""
    payload = {
        "app": "RemoteFlowMax",
        "ip": ip,
        "ws_port": ws_port,
        "udp_port": udp_port,
        "name": server_name
    }
    return json.dumps(payload, separators=(',', ':'))

def print_qr_code(data: str):
    """Prints high-contrast ASCII QR code directly to standard console."""
    try:
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=1,
            border=1
        )
        qr.add_data(data)
        qr.make(fit=True)

        output = StringIO()
        qr.print_ascii(out=output, invert=True)
        print(output.getvalue())
    except Exception as e:
        logger.warning(f"Could not render terminal QR code: {e}")
