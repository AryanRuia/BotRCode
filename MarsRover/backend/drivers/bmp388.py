"""BMP388 wrapper with graceful fallback"""

try:
    import board
    import busio
    import adafruit_bmp3xx
    hw = True
except Exception:
    hw = False


def read_pressure_temp():
    if not hw:
        return {"pressure_hpa": 1013.25, "temperature_c": 20.0}
    try:
        i2c = busio.I2C(board.SCL, board.SDA)
        sensor = adafruit_bmp3xx.BMP3XX_I2C(i2c)
        return {"pressure_hpa": sensor.pressure, "temperature_c": sensor.temperature}
    except Exception as e:
        return {"error": str(e)}
