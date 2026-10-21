"""
RemoteFlow Max - Network Security & PIN Authentication Engine
Generates dynamic session PINs and auth tokens for secure mobile-to-PC pairing.
"""

import random
import secrets
import logging
from typing import Optional

logger = logging.getLogger("RemoteFlow.Auth")

class AuthEngine:
    def __init__(self, pin_enabled: bool = False, default_pin: Optional[str] = None):
        self.pin_enabled = pin_enabled
        # Generate clean 4-digit session PIN or use provided
        self.session_pin = default_pin or f"{random.randint(1000, 9999)}"
        self.auth_token = secrets.token_hex(16)

    def enable_pin(self, enable: bool = True):
        self.pin_enabled = enable
        logger.info(f"[Auth] PIN protection {'ENABLED' if enable else 'DISABLED'}. PIN: {self.session_pin}")

    def verify_pin(self, pin: str) -> bool:
        """Verifies if user-supplied PIN matches host session PIN."""
        if not self.pin_enabled:
            return True
        return str(pin).strip() == str(self.session_pin).strip()

    def verify_token(self, token: str) -> bool:
        """Verifies session auth token."""
        return secrets.compare_digest(str(token), str(self.auth_token))

    def regenerate_pin(self) -> str:
        self.session_pin = f"{random.randint(1000, 9999)}"
        self.auth_token = secrets.token_hex(16)
        logger.info(f"[Auth] New session PIN generated: {self.session_pin}")
        return self.session_pin
