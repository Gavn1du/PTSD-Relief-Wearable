import time
import board
import busio
from adafruit_lsm6ds.lsm6dsox import LSM6DSOX

i2c = busio.I2C(board.SCL, board.SDA)
sox = LSM6DSOX(i2c)
sox.accelerometer_range = 2
sox.accelerometer_data_rate = 208 # in Hz
FS = 208
DT = 1.0 / FS

WINDOW_SEC = 1.0
N = int(WINDOW_SEC * FS)
HPF_CUTOFF = 0.7 # remove gravity and low freq. motion
BAND_LO = 2
BAND_HIGH = 12
FREQS = list(range(BAND_LO, BAND_HIGH + 1))

# instability thresholds (psychogenic tremor detection)
MIN_RMS_G = 0.02 # ignore very small motions
MIN_BAND_RATIO = 0.25 # band/total power ratio



# --- High-pass filter ---



# --- Goertzel ---



# --- Main loop ---
while True:
	print("acceleration: x: %.2f, y: %.2f, z: %.2f"%(sox.acceleration))
	print("gyro: x: %.2f, y: %.2f, z: %.2f"%(sox.gyro))
	print("")

	time.sleep(0.5) 
	
    