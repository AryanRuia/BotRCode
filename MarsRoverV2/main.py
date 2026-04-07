import io
import time
import math
import threading
import board
import serial
import logging
from adafruit_bmp3xx import BMP3XX_I2C
from adafruit_lsm6ds.lsm6dsox import LSM6DSOX
from flask import Flask, Response
from picamera2 import Picamera2
from PIL import Image
from gpiozero import Motor

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

# --- MOTOR SETUP ---
# IMPORTANT: Replace these GPIO pin numbers with your actual wiring!
# format: Motor(forward=DIR1, backward=DIR2, enable=PWM_PIN)
left_motor = Motor(forward=19, backward=16, enable=12)
right_motor = Motor(forward=26, backward=20, enable=13)

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

def execute_vector(target_angle, target_magnitude):
    """Executes a polar vector: Turns first, then drives forward."""
    logger.info(f"Executing Vector: Angle={target_angle}, Mag={target_magnitude}")
    
    # --- PHASE 1: TURN ---
    current_angle = 0.0
    last_time = time.time()
    
    # Turn by moving one motor, keeping the other still
    if target_angle > 0: # Turn Right
        left_motor.forward(0.7) # 70% speed
        right_motor.stop()
    elif target_angle < 0: # Turn Left
        right_motor.forward(0.7)
        left_motor.stop()
        
    while abs(current_angle) < abs(target_angle):
        current_time = time.time()
        dt = current_time - last_time
        last_time = current_time
        
        # Read Gyro Z-axis (radians/sec) and convert to degrees
        gyro_z = lsm.gyro[2] 
        current_angle += math.degrees(gyro_z) * dt
        time.sleep(0.01) # 100Hz sample rate
        
    left_motor.stop()
    right_motor.stop()
    time.sleep(0.5) # Let the rover settle
    
    # --- PHASE 2: DRIVE FORWARD ---
    if target_magnitude > 0:
        distance = 0.0
        velocity = 0.0
        last_time = time.time()
        
        left_motor.forward(0.8)
        right_motor.forward(0.8)
        
        while distance < target_magnitude:
            current_time = time.time()
            dt = current_time - last_time
            last_time = current_time
            
            # Read Accel Y-axis (m/s^2) - Assume Y is the forward axis
            accel_y = lsm.acceleration[1]
            
            # Deadband filter: ignore tiny vibrations to reduce drift
            if abs(accel_y) < 0.15: 
                accel_y = 0 
                
            velocity += accel_y * dt
            distance += abs(velocity * dt)
            time.sleep(0.01)
            
        left_motor.stop()
        right_motor.stop()
        logger.info("Movement complete.")

def xbee_broadcast_and_receive_loop():
    """Reads sensors, sends telemetry, and listens for commands"""
    last_broadcast = time.time()
    while True:
        try:
            # 1. Listen for incoming commands
            if xbee_ser.in_waiting > 0:
                line = xbee_ser.readline().decode('utf-8').strip()
                if line.startswith("CMD:VEC"):
                    parts = line.split('|')
                    angle = float(parts[1].split(':')[1])
                    mag = float(parts[2].split(':')[1])
                    # Run movement in a separate thread so telemetry doesn't freeze
                    threading.Thread(target=execute_vector, args=(angle, mag), daemon=True).start()

            # 2. Broadcast telemetry at ~2Hz
            if time.time() - last_broadcast > 0.5:
                accel = lsm.acceleration
                data = f"P:{bmp.pressure:.1f}|T:{bmp.temperature:.1f}|AX:{accel[0]:.2f}|AY:{accel[1]:.2f}|AZ:{accel[2]:.2f}\n"
                xbee_ser.write(data.encode())
                last_broadcast = time.time()
                
            time.sleep(0.05)
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
    threading.Thread(target=xbee_broadcast_and_receive_loop, daemon=True).start()
    app.run(host='0.0.0.0', port=5000, threaded=True)