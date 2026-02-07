from collection import deque

class MotionDetector:
    """
    Fall/Tremor detector using accelerometer data.
    Assumptions:
        - user is not exercising
        - devices axes are consistent with wear orientation
    """

    def __init__(self, session_id, axis_map=None):
        self.session_id = session_id

        if axis_map:
            self.axis_map = axis_map
        else:
            self.axis_map = {
                "vertical": "y",
                "lateral": "x",
                "forward": "z"
            }
        
        self.g = 9.81

        # Data Buffer (~3 seconds)
        self.buffer = deque(maxlen=15)

        # State Machine
        self.state = "IDLE"
        self.freefall_start_ms = None
        self.impact_ms = None
        self.post_start_ms = None

        # Debounce
        self.last_event_ms = 0
        self.event_cooldown_ms = 2500

        # Timers
        self.last_tremor_check_ms = 0
        self.tremor_active_until_ms = 0


        # === THRESHOLDS ===
        # Fall Signals
        self.FREEFALL_MAG_MAX = 3.0 # acceleration needed to detect fall
        self.FREEFALL_MIN_MS = 180 # minimum duration of the movement to register
        self.IMPACT_MAG_MIN = 22.0 # spike detection
        self.POST_WINDOW_MS = 1500 # post-assessment time

        # Tumbling
        self.TUMBLE_JERK_MIN = 80.0
        self.TUMBLE_BURSTS_IN = 2

        # Stumbling
        self.STUMBLE_JERK_MIN = 50.0
        self.STUMBLE_WINDOW_MS = 800
        self.RECOVER_STABLE_MS = 700

        # Tremors
        

        # Recovery

        # General False Flags