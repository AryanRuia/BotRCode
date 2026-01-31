"""LSM6DSOX wrapper with graceful fallback when hardware not available"""

import os

try:
    import board
    import busio
    from adafruit_lsm6ds import LSM6DSOX
    hw = True
except Exception:
    hw = False


def read_imu():
    if not hw:
        # Return fake data for development
        return {"accel": [0.0, 0.0, 9.81], "gyro": [0.0, 0.0, 0.0]}
    try:
        i2c = busio.I2C(board.SCL, board.SDA)
        sensor = LSM6DSOX(i2c)
        accel = sensor.acceleration
        gyro = sensor.gyro
        return {"accel": accel, "gyro": gyro}
    except Exception as e:
        return {"error": str(e)}
