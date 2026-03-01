#!/usr/bin/env python3
"""
Mars Rover Camera Streaming System
Streams IMX519 camera footage via MJPEG over HTTP
Minimal dependencies for RPi 5
"""

import io
import time
import threading
import board
import busio
from adafruit_bmp3xx import BMP3XX_I2C
from adafruit_lsm6ds.lsm6dsox import LSM6DSOX
from flask import Flask, render_template, Response
from picamera2 import Picamera2, Preview
from picamera2.encoders import MJPEGEncoder
from picamera2.outputs import FileOutput
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Flask app initialization
app = Flask(__name__, template_folder='../templates')

# Global camera instance
camera = None
camera_lock = threading.Lock()
current_frame = None

# Camera configuration
CAMERA_RESOLUTION = (1280, 720)  # IMX519 supports up to 4K, adjust as needed
CAMERA_FPS = 30
JPEG_QUALITY = 85


def initialize_camera():
    """Initialize the IMX519 camera"""
    global camera
    
    try:
        logger.info("Initializing IMX519 camera...")
        camera = Picamera2()
        
        # Configure camera with optimized settings
        config = camera.create_video_configuration(
            main={"size": CAMERA_RESOLUTION, "format": "BGR888"},
            controls={"FrameRate": CAMERA_FPS}
        )
        
        camera.configure(config)
        camera.start()
        logger.info(f"Camera initialized: {CAMERA_RESOLUTION} @ {CAMERA_FPS}FPS")
        return True
        
    except Exception as e:
        logger.error(f"Failed to initialize camera: {e}")
        return False


def capture_frames():
    """Continuously capture frames from camera"""
    global current_frame
    
    if camera is None:
        logger.error("Camera not initialized")
        return
    
    try:
        logger.info("Starting frame capture loop...")
        while True:
            try:
                with camera_lock:
                    # Capture frame as JPEG
                    frame = camera.capture_array("main")
                    
                    # Convert to JPEG bytes
                    from PIL import Image
                    img = Image.fromarray(frame)
                    buffer = io.BytesIO()
                    img.save(buffer, format='JPEG', quality=JPEG_QUALITY)
                    current_frame = buffer.getvalue()
                
                time.sleep(1.0 / CAMERA_FPS)  # Maintain FPS
                
            except Exception as e:
                logger.error(f"Error capturing frame: {e}")
                time.sleep(0.1)
                
    except KeyboardInterrupt:
        logger.info("Frame capture stopped")


def generate_mjpeg():
    """Generator for MJPEG stream"""
    boundary = b'--MJPEGBOUNDARY'
    
    logger.info("MJPEG stream requested")
    try:
        while True:
            if current_frame is not None:
                with camera_lock:
                    frame_data = current_frame
                
                # MJPEG boundary and headers
                yield boundary + b'\r\n'
                yield b'Content-Type: image/jpeg\r\n'
                yield b'Content-Length: ' + str(len(frame_data)).encode() + b'\r\n'
                yield b'\r\n'
                yield frame_data
                yield b'\r\n'
            else:
                time.sleep(0.01)
                
    except GeneratorExit:
        logger.info("MJPEG stream closed")


@app.route('/')
def index():
    """Serve main page"""
    return render_template('index.html')


@app.route('/stream')
def stream():
    """Serve MJPEG video stream"""
    return Response(
        generate_mjpeg(),
        mimetype='multipart/x-mixed-replace; boundary=--MJPEGBOUNDARY'
    )

i2c = board.I2C()
bmp = BMP3XX_I2C(i2c)
lsm = LSM6DSOX(i2c)

@app.route('/status')
def status():
    accel_x, accel_y, accel_z = lsm.acceleration
    gyro_x, gyro_y, gyro_z = lsm.gyro
    """Return system status"""
    return {
        'status': 'running',
        'camera': 'initialized' if camera is not None else 'not initialized',
        'telemetry': {
            'pressure': round(bmp.pressure, 2),
            'temp': round(bmp.temperature, 2),
            'accel': [round(accel_x, 2), round(accel_y, 2), round(accel_z, 2)],
            'gyro': [round(gyro_x, 2), round(gyro_y, 2), round(gyro_z, 2)]
        },
        'resolution': CAMERA_RESOLUTION,
        'fps': CAMERA_FPS
    }


def main():
    """Main entry point"""
    logger.info("=" * 50)
    logger.info("Mars Rover Streaming System")
    logger.info("=" * 50)
    
    # Initialize camera
    if not initialize_camera():
        logger.error("Failed to initialize camera. Exiting.")
        return 1
    
    # Start frame capture in background thread
    capture_thread = threading.Thread(target=capture_frames, daemon=True)
    capture_thread.start()
    logger.info("Frame capture thread started")
    
    # Start Flask server
    logger.info("Starting web server on 0.0.0.0:5000")
    logger.info("Access streaming at: http://192.168.4.1:5000")
    
    try:
        app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
    except KeyboardInterrupt:
        logger.info("Shutting down...")
    finally:
        if camera is not None:
            camera.stop()
            logger.info("Camera stopped")
    
    return 0


if __name__ == '__main__':
    exit(main())
