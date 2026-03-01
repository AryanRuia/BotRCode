import board
import busio
import time
from adafruit_bmp3xx import BMP3XX_I2C
from adafruit_lsm6ds.lsm6dsox import LSM6DSOX

try:
    i2c = board.I2C()
    bmp = BMP3XX_I2C(i2c)
    lsm = LSM6DSOX(i2c)

    print("Sensors detected! Reading data...")
    while True:
        print(f"Temp: {bmp.temperature:.2f}C | Pressure: {bmp.pressure:.2f}hPa")
        print(f"Accel: {lsm.acceleration} | Gyro: {lsm.gyro}")
        time.sleep(1)
except Exception as e:
    print(f"Error: {e}")