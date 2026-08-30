import unittest

from motion_detection import MotionDetector


class MotionDetectorTest(unittest.TestCase):
    def test_freefall_impact_and_unstable_motion_is_a_real_fall(self):
        detector = MotionDetector(session_id="test")
        now_ms = 1_000_000
        samples = []

        for _ in range(15):
            samples.append((now_ms, 0.2, 0.2, 0.2))
            now_ms += 20

        samples.append((now_ms, 28.0, 4.0, 3.0))
        now_ms += 20

        for index in range(80):
            # A 5 Hz oscillation resembles a tremor, but after an impact the
            # in-progress fall sequence must take classification priority.
            value = 18.0 if (index // 5) % 2 == 0 else 2.0
            samples.append((now_ms, value, value / 2, 6.0))
            now_ms += 20

        fall_event = None
        for sample in samples:
            event = detector.update(*sample, fs_hz=50.0)
            if event and event["kind"] in {
                "real_tumbling",
                "real_tripping",
                "real_slipping",
            }:
                fall_event = event
                break

        self.assertIsNotNone(fall_event)


if __name__ == "__main__":
    unittest.main()
