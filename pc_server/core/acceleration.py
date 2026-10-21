"""
RemoteFlow Max - Non-Linear Mouse Acceleration & Precision Curves
Provides sub-pixel accumulation, sniper mode, fast mode, and inertia smoothing.
"""

import math
from pc_server.config import (
    DEFAULT_SENSITIVITY,
    SNIPER_MULTIPLIER,
    FAST_MULTIPLIER,
    ACCELERATION_POWER,
    ACCELERATION_COEFFICIENT,
    SCROLL_MULTIPLIER
)

class MouseAccelerationEngine:
    def __init__(self, base_sensitivity: float = DEFAULT_SENSITIVITY):
        self.base_sensitivity = base_sensitivity
        self.accum_x: float = 0.0
        self.accum_y: float = 0.0
        self.accum_scroll_y: float = 0.0
        self.accum_scroll_x: float = 0.0

    def set_sensitivity(self, sensitivity: float):
        self.base_sensitivity = max(0.1, min(10.0, sensitivity))

    def process_delta(self, raw_dx: float, raw_dy: float, mode: str = "normal") -> tuple[int, int]:
        """
        Applies dynamic non-linear acceleration curve and sub-pixel accumulation.
        Returns integer pixel displacement (dx, dy).
        """
        # Determine mode multiplier
        mode_lower = (mode or "normal").lower()
        if mode_lower == "sniper":
            multiplier = SNIPER_MULTIPLIER
            enable_accel = False
        elif mode_lower == "fast":
            multiplier = FAST_MULTIPLIER
            enable_accel = True
        else:
            multiplier = 1.0
            enable_accel = True

        magnitude = math.hypot(raw_dx, raw_dy)
        if magnitude < 0.0001:
            return 0, 0

        # Base scaling
        scale = self.base_sensitivity * multiplier

        if enable_accel and magnitude > 2.5:
            # Dynamic non-linear acceleration for high-speed flicks
            # Allows slow micro-movements to remain 1:1, while fast swipes jump across 4K displays
            accel_boost = 1.0 + ACCELERATION_COEFFICIENT * math.pow(magnitude - 2.5, ACCELERATION_POWER)
            scale *= accel_boost

        scaled_dx = raw_dx * scale
        scaled_dy = raw_dy * scale

        # Sub-pixel accumulator
        self.accum_x += scaled_dx
        self.accum_y += scaled_dy

        out_dx = int(self.accum_x)
        out_dy = int(self.accum_y)

        self.accum_x -= out_dx
        self.accum_y -= out_dy

        return out_dx, out_dy

    def process_scroll(self, raw_dy: float, raw_dx: float = 0.0) -> tuple[int, int]:
        """
        Process two-finger scroll delta to standard Windows wheel increments (120 units per notch).
        """
        scaled_y = raw_dy * SCROLL_MULTIPLIER
        scaled_x = raw_dx * SCROLL_MULTIPLIER

        self.accum_scroll_y += scaled_y
        self.accum_scroll_x += scaled_x

        step_y = int(self.accum_scroll_y)
        step_x = int(self.accum_scroll_x)

        self.accum_scroll_y -= step_y
        self.accum_scroll_x -= step_x

        return step_x, step_y

    def reset_accumulator(self):
        """Reset sub-pixel accumulation on gesture end/touch lift."""
        self.accum_x = 0.0
        self.accum_y = 0.0
        self.accum_scroll_y = 0.0
        self.accum_scroll_x = 0.0
