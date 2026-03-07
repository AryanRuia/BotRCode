import io
import time
import threading
import board
import serial
import logging
from adafruit_bmp3xx import BMP3XX_I2C
from adafruit_lsm6ds.lsm6dsox import LSM6DSOX
from flask import Flask, Response
from picamera2 import Picamera2
from PIL import Image

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
camera = None
camera_lock = threading.Lock()
current_frame = None

# UART setup for XBee
xbee_ser = serial.Serial('/dev/ttyAMA0', 9600, timeout=1)
i2c = board.I2C()
bmp = BMP3XX_I2C(i2c)
lsm = LSM6DSOX(i2c)

def initialize_camera():
    global camera
    try:
        camera = Picamera2()
        config = camera.create_video_configuration(
            main={"size": (1280, 720), "format": "BGR888"},
            controls={"FrameRate": 30}
        )
        camera.configure(config)
        camera.start()
        return True
    except Exception as e:
        logger.error(f"Camera error: {e}")
        return False

def xbee_broadcast_loop():
    """Reads sensors and sends telemetry over XBee"""
    while True:
        try:
            accel = lsm.acceleration
            # Format: P:pressure|T:temp|AX:x|AY:y|AZ:z
            data = f"P:{bmp.pressure:.1f}|T:{bmp.temperature:.1f}|AX:{accel[0]:.2f}|AY:{accel[1]:.2f}|AZ:{accel[2]:.2f}\n"
            xbee_ser.write(data.encode())
            time.sleep(0.5) 
        except Exception as e:
            logger.error(f"XBee error: {e}")
            time.sleep(1)

def capture_frames():
    global current_frame
    while True:
        with camera_lock:
            frame = camera.capture_array("main")
            img = Image.fromarray(frame)
            buffer = io.BytesIO()
            img.save(buffer, format='JPEG', quality=70) # Lower quality for range
            current_frame = buffer.getvalue()
        time.sleep(0.05)

@app.route('/stream')
def stream():
    def generate():
        while True:
            if current_frame:
                yield (b'--frame\r\n' b'Content-Type: image/jpeg\r\n\r\n' + current_frame + b'\r\n')
            time.sleep(0.05)
    return Response(generate(), mimetype='multipart/x-mixed-replace; boundary=frame')

if __name__ == '__main__':
    initialize_camera()
    threading.Thread(target=capture_frames, daemon=True).start()
    threading.Thread(target=xbee_broadcast_loop, daemon=True).start()
    app.run(host='0.0.0.0', port=5000, threaded=True)