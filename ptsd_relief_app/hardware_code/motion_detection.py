from collections import deque
import math


class MotionDetector:
    """
    Fall/Tremor detector using accelerometer data.

    Assumptions:
        - user is not exercising
        - device axes are consistent with wear orientation
        - you pass consistent timestamps (ms) and an estimated sample rate (fs_hz)

    Output:
        update(...) returns either None or an event dict:
            {"kind": "<label>", "detail": {...}}  OR  {"kind": "<label>", "score": <float>, "detail": {...}}
    """

    def __init__(self, session_id, axis_map=None):
        self.session_id = session_id

        self.axis_map = axis_map or {
            "vertical": "y",
            "lateral": "x",
            "forward": "z"
        }

        self.g = 9.81

        # Data buffer (timestamped). NOTE: maxlen should reflect your poll rate.
        # If you're at ~50 Hz and want ~3 seconds, use ~150. Your current 15 is ~0.3s at 50 Hz.
        self.buffer = deque(maxlen=150)  # ~3s @ 50Hz

        # State machine
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
        # Fall signals
        self.FREEFALL_MAG_MAX = 3.0    # near 0g region (m/s^2)
        self.FREEFALL_MIN_MS  = 180    # minimum duration to qualify freefall
        self.IMPACT_MAG_MIN   = 22.0   # impact spike threshold (m/s^2)
        self.POST_WINDOW_MS   = 1500   # post-impact assessment window

        # Tumbling
        self.TUMBLE_JERK_MIN   = 80.0  # magnitude jerk threshold (m/s^3)
        self.TUMBLE_BURSTS_N   = 2     # bursts in post window to call "tumbling"

        # Stumbling (recover cases)
        self.STUMBLE_JERK_MIN   = 50.0
        self.STUMBLE_WINDOW_MS  = 800
        self.RECOVER_STABLE_MS  = 700

        # Tremors (simple oscillation heuristic)
        self.TREMOR_WIN_MS          = 1800
        self.TREMOR_CHECK_EVERY_MS  = 400
        self.TREMOR_MIN_HZ          = 4.0
        self.TREMOR_MAX_HZ          = 12.0
        self.TREMOR_AXIS_STD_MIN    = 0.35   # m/s^2 (tune)
        self.TREMOR_HOLD_MS         = 1200

        # Recovery / Jump stabilization
        self.STABLE_MAG_EPS     = 1.8   # |mag - g| <= eps considered stable
        self.STABLE_MIN_MS      = 600   # "quick stabilize" threshold after impact

        # General false-flag suppression
        self.CLAP_HANDSHAKE_JERK_MIN = 95.0  # short violent jerk without freefall/impact structure
        self.WALK_RUN_MIN_HZ         = 0.8   # if you later allow exercise, use these to suppress
        self.WALK_RUN_MAX_HZ         = 3.2
        self.AXIS_DOM_RATIO          = 1.15  # dominance ratio for trip vs slip

    # --------------------- helpers ---------------------
    def _axis(self, ax, ay, az, axis_name):
        if axis_name == "x":
            return ax
        if axis_name == "y":
            return ay
        return az

    def _window(self, now_ms, win_ms):
        cutoff = now_ms - win_ms
        return [s for s in self.buffer if s[0] >= cutoff]  # (t, ax, ay, az, mag)

    def _jerk_mag_series(self, window):
        if len(window) < 3:
            return []
        out = []
        for i in range(1, len(window)):
            t0, _, _, _, m0 = window[i - 1]
            t1, _, _, _, m1 = window[i]
            dt = (t1 - t0) / 1000.0
            if dt <= 0:
                continue
            out.append((m1 - m0) / dt)  # m/s^3
        return out

    def _stable_ms(self, window):
        if len(window) < 2:
            return 0
        stable = 0
        consec = 0
        for i in range(1, len(window)):
            t0, _, _, _, _ = window[i - 1]
            t1, _, _, _, m1 = window[i]
            if abs(m1 - self.g) <= self.STABLE_MAG_EPS:
                consec += (t1 - t0)
                stable = max(stable, consec)
            else:
                consec = 0
        return stable

    def _std(self, xs):
        n = len(xs)
        if n < 2:
            return 0.0
        mu = sum(xs) / n
        var = sum((x - mu) ** 2 for x in xs) / (n - 1)
        return math.sqrt(var)

    def _zero_cross_hz(self, xs, duration_s):
        """
        Very lightweight frequency estimator:
          sign changes / (2 * duration)
        Works well enough for tremor band detection when the signal is reasonably sinusoidal.
        """
        if len(xs) < 6 or duration_s <= 0:
            return 0.0
        # remove DC
        mu = sum(xs) / len(xs)
        ys = [x - mu for x in xs]
        crosses = 0
        prev = ys[0]
        for y in ys[1:]:
            if (prev <= 0 < y) or (prev >= 0 > y):
                crosses += 1
            prev = y
        return crosses / (2.0 * duration_s)

    # --------------------- tremor detection ---------------------
    def _detect_tremor(self, now_ms, fs_hz):
        if now_ms < self.tremor_active_until_ms:
            return None
        if (now_ms - self.last_tremor_check_ms) < self.TREMOR_CHECK_EVERY_MS:
            return None
        self.last_tremor_check_ms = now_ms

        win = self._window(now_ms, self.TREMOR_WIN_MS)
        if len(win) < max(12, int(0.5 * fs_hz)):
            return None

        # pull axis signals
        v_axis = self.axis_map["vertical"]
        l_axis = self.axis_map["lateral"]

        v_vals = [self._axis(ax, ay, az, v_axis) for (_, ax, ay, az, _) in win]
        l_vals = [self._axis(ax, ay, az, l_axis) for (_, ax, ay, az, _) in win]

        # duration from timestamps is more robust than assuming fs_hz
        duration_s = (win[-1][0] - win[0][0]) / 1000.0
        if duration_s <= 0:
            return None

        # amplitude proxy
        v_std = self._std(v_vals)
        l_std = self._std(l_vals)
        if v_std < self.TREMOR_AXIS_STD_MIN and l_std < self.TREMOR_AXIS_STD_MIN:
            return None

        # frequency proxy (ZCR)
        v_hz = self._zero_cross_hz(v_vals, duration_s)
        l_hz = self._zero_cross_hz(l_vals, duration_s)

        # suppress likely walking/running (if ever present): dominant 1–3 Hz vertical oscillation
        # (Given your "not exercising" assumption, this mainly helps avoid false tremor alarms.)
        if self.WALK_RUN_MIN_HZ <= v_hz <= self.WALK_RUN_MAX_HZ and v_std > (self.TREMOR_AXIS_STD_MIN * 1.5):
            return None

        def in_band(hz):
            return self.TREMOR_MIN_HZ <= hz <= self.TREMOR_MAX_HZ

        # classify tremor direction
        if in_band(v_hz) and (v_std >= l_std * 1.10):
            self.tremor_active_until_ms = now_ms + self.TREMOR_HOLD_MS
            return {
                "kind": "tremor_up_down",
                "score": v_std,
                "detail": {"hz": v_hz, "std": v_std, "win_ms": self.TREMOR_WIN_MS}
            }

        if in_band(l_hz) and (l_std >= v_std * 1.10):
            self.tremor_active_until_ms = now_ms + self.TREMOR_HOLD_MS
            return {
                "kind": "tremor_left_right",
                "score": l_std,
                "detail": {"hz": l_hz, "std": l_std, "win_ms": self.TREMOR_WIN_MS}
            }

        return None

    # --------------------- fall classification ---------------------
    def _classify_fall(self, now_ms):
        """
        Called once post window is complete.
        Returns:
            - real_tumbling
            - real_tripping
            - real_slipping
            - fake_jumping
            - None
        """
        if self.impact_ms is None:
            return None

        pre = self._window(self.impact_ms, 450)
        post = self._window(self.impact_ms + self.POST_WINDOW_MS, self.POST_WINDOW_MS)

        if len(pre) < 8 or len(post) < 12:
            return None

        # tumbling detection by counting high jerk bursts in post window
        jerks_post = self._jerk_mag_series(post)
        tumble_bursts = sum(1 for j in jerks_post if abs(j) >= self.TUMBLE_JERK_MIN)

        stable_ms = self._stable_ms(post)

        # Jump signature: freefall + impact + quick stabilize + not tumbling
        if stable_ms >= self.STABLE_MIN_MS and tumble_bursts < self.TUMBLE_BURSTS_N:
            return {
                "kind": "fake_jumping",
                "detail": {"stable_ms": stable_ms, "tumble_bursts": tumble_bursts}
            }

        # Tumbling fall
        if tumble_bursts >= self.TUMBLE_BURSTS_N:
            return {
                "kind": "real_tumbling",
                "detail": {"tumble_bursts": tumble_bursts, "stable_ms": stable_ms}
            }

        # Otherwise: try to decide trip vs slip by axis dominance right before impact
        fwd_axis = self.axis_map["forward"]
        lat_axis = self.axis_map["lateral"]

        fwd_vals = [self._axis(ax, ay, az, fwd_axis) for (_, ax, ay, az, _) in pre]
        lat_vals = [self._axis(ax, ay, az, lat_axis) for (_, ax, ay, az, _) in pre]

        # remove DC per-axis
        fwd_mu = sum(fwd_vals) / len(fwd_vals)
        lat_mu = sum(lat_vals) / len(lat_vals)
        fwd_dyn = [v - fwd_mu for v in fwd_vals]
        lat_dyn = [v - lat_mu for v in lat_vals]

        fwd_e = sum(abs(v) for v in fwd_dyn) / len(fwd_dyn)
        lat_e = sum(abs(v) for v in lat_dyn) / len(lat_dyn)

        if fwd_e >= lat_e * self.AXIS_DOM_RATIO:
            return {"kind": "real_tripping", "detail": {"fwd_e": fwd_e, "lat_e": lat_e}}
        if lat_e >= fwd_e * self.AXIS_DOM_RATIO:
            return {"kind": "real_slipping", "detail": {"fwd_e": fwd_e, "lat_e": lat_e}}

        # ambiguous: default to tripping
        return {"kind": "real_tripping", "detail": {"fwd_e": fwd_e, "lat_e": lat_e, "note": "ambiguous"}}

    # --------------------- stumble + recover ---------------------
    def _detect_recover_stumble(self, now_ms):
        """
        Detect:
            - fake_trip_recover
            - fake_slip_recover
        Pattern:
            - jerk burst in last STUMBLE_WINDOW_MS
            - no big impact
            - stable near end
        """
        win = self._window(now_ms, self.STUMBLE_WINDOW_MS)
        if len(win) < 10:
            return None

        mags = [s[4] for s in win]
        if max(mags) >= self.IMPACT_MAG_MIN:
            return None  # if impact, let fall logic handle it

        jerks = self._jerk_mag_series(win)
        if not jerks:
            return None

        peak_jerk = max(abs(j) for j in jerks)
        if peak_jerk < self.STUMBLE_JERK_MIN:
            return None

        stable_ms = self._stable_ms(win)
        if stable_ms < self.RECOVER_STABLE_MS:
            return None

        # suppress claps/handshakes (often very short, huge jerk, but not a stumble)
        # heuristic: extremely high jerk + very short window stability pattern
        if peak_jerk >= self.CLAP_HANDSHAKE_JERK_MIN and len(win) < 18:
            return None

        fwd_axis = self.axis_map["forward"]
        lat_axis = self.axis_map["lateral"]

        fwd_vals = [self._axis(ax, ay, az, fwd_axis) for (_, ax, ay, az, _) in win]
        lat_vals = [self._axis(ax, ay, az, lat_axis) for (_, ax, ay, az, _) in win]

        fwd_mu = sum(fwd_vals) / len(fwd_vals)
        lat_mu = sum(lat_vals) / len(lat_vals)
        fwd_dyn = [v - fwd_mu for v in fwd_vals]
        lat_dyn = [v - lat_mu for v in lat_vals]

        fwd_e = sum(abs(v) for v in fwd_dyn) / len(fwd_dyn)
        lat_e = sum(abs(v) for v in lat_dyn) / len(lat_dyn)

        if fwd_e >= lat_e * self.AXIS_DOM_RATIO:
            return {"kind": "fake_trip_recover", "detail": {"peak_jerk": peak_jerk, "stable_ms": stable_ms}}
        if lat_e >= fwd_e * self.AXIS_DOM_RATIO:
            return {"kind": "fake_slip_recover", "detail": {"peak_jerk": peak_jerk, "stable_ms": stable_ms}}

        return {"kind": "fake_trip_recover", "detail": {"peak_jerk": peak_jerk, "stable_ms": stable_ms, "note": "ambiguous"}}

    def _reset_fall_state(self):
        self.state = "IDLE"
        self.freefall_start_ms = None
        self.impact_ms = None
        self.post_start_ms = None

    # --------------------- public API ---------------------
    def update(self, now_ms, ax, ay, az, fs_hz=50.0):
        """
        Feed one accel sample.

        Args:
            now_ms: int timestamp in ms
            ax, ay, az: float accel (m/s^2)
            fs_hz: estimated sample rate

        Returns:
            event dict or None
        """
        mag = math.sqrt(ax * ax + ay * ay + az * az)
        self.buffer.append((now_ms, ax, ay, az, mag))

        # Tremors can be detected even during cooldown
        trem = self._detect_tremor(now_ms, fs_hz)
        if trem:
            return trem

        # Debounce fall/stumble events
        if (now_ms - self.last_event_ms) < self.event_cooldown_ms:
            return None

        # False-flag: strong jerk but no freefall/impact structure -> ignore
        recent = self._window(now_ms, 400)
        if len(recent) >= 6:
            mags = [s[4] for s in recent]
            jerks = self._jerk_mag_series(recent)
            if jerks:
                peak = max(abs(j) for j in jerks)
                if peak >= self.CLAP_HANDSHAKE_JERK_MIN:
                    if min(mags) > self.FREEFALL_MAG_MAX and max(mags) < self.IMPACT_MAG_MIN:
                        return None

        # ----------------- Fall state machine -----------------
        if self.state == "IDLE":
            if mag < self.FREEFALL_MAG_MAX:
                if self.freefall_start_ms is None:
                    self.freefall_start_ms = now_ms
                if (now_ms - self.freefall_start_ms) >= self.FREEFALL_MIN_MS:
                    self.state = "FREEFALL"
            else:
                self.freefall_start_ms = None

            # If not in fall sequence, check stumble-recover
            evt = self._detect_recover_stumble(now_ms)
            if evt:
                self.last_event_ms = now_ms
                return evt

        elif self.state == "FREEFALL":
            # Impact detection
            if mag >= self.IMPACT_MAG_MIN:
                self.impact_ms = now_ms
                self.post_start_ms = now_ms
                self.state = "POST"

            # Abort if too long without impact (could be device thrown)
            if self.freefall_start_ms and (now_ms - self.freefall_start_ms) > 1200:
                self._reset_fall_state()

        elif self.state == "POST":
            if self.post_start_ms and (now_ms - self.post_start_ms) >= self.POST_WINDOW_MS:
                evt = self._classify_fall(now_ms)
                self._reset_fall_state()
                if evt:
                    self.last_event_ms = now_ms
                    return evt

        return None
