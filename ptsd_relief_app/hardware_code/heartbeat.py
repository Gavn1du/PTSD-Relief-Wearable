import board
import busio
import adafruit_ads1x15.ads1115 as ADS
from adafruit_ads1x15.analog_in import AnalogIn
import time

i2c = busio.I2C(board.SCL, board.SDA)
ads = ADS.ADS1115(i2c)
ads.gain = 1
ads.data_rate = 250
heartrate_sensor = AnalogIn(ads, ADS.P3)

SAMPLE_HZ = 250
DT = 1.0 / SAMPLE_HZ
WINDOW_SEC = 15
REFRACTORY_SEC = 0.3
ALPHA_BASELINE = 0.01
ALPHA_NOISE = 0.01
THRESHOLD_MULTIPLIER = 1.5

baseline = heartrate_sensor.value
noise = 0

beats_in_window = 0
last_cross_up = False
last_beat_time = -1e9
window_start = time.monotonic()

warmup_end = time.monotonic() + 5.0

while True:
    v = heartrate_sensor.value

    baseline = (1 - ALPHA_BASELINE) * baseline + ALPHA_BASELINE * v
    dev = abs(v - baseline)
    noise = (1 - ALPHA_NOISE) * noise + ALPHA_NOISE * dev

    threshold = baseline + THRESHOLD_MULTIPLIER * max(noise, 1)
    now = time.monotonic()

    is_above = v > threshold
    rising_cross = (not last_cross_up) and is_above
    if rising_cross and (now - last_beat_time) >= REFRACTORY_SEC and now >= warmup_end:
        beats_in_window += 1
        last_beat_time = now
    
    last_cross_up = is_above

    if now - window_start >= WINDOW_SEC:
        bpm = int(round((beats_in_window / WINDOW_SEC) * 60))
        print(f"Heart Rate: {bpm} BPM")
        beats_in_window = 0
        window_start = now
    
    time.sleep(DT)