
import time
import board
import busio
import serial
import cv2
import adafruit_bmp3xx
from adafruit_lsm6ds.lsm6dsox import LSM6DSOX

def initialize_sensors():
    """Initialize I2C sensors (BMP388 and LSM6DSOX)."""
    try:
        i2c = board.I2C()  # uses board.SCL and board.SDA
        bmp = adafruit_bmp3xx.BMP3XX_I2C(i2c)
        lsm = LSM6DSOX(i2c)
        print("[SUCCESS] Sensors initialized.")
        return bmp, lsm
    except Exception as e:
        print(f"[ERROR] Sensor initialization failed: {e}")
        return None, None

def initialize_xbee(port='/dev/serial0', baudrate=9600):
    """Initialize XBee serial connection."""
    try:
        # Common Pi serial ports: /dev/serial0, /dev/ttyS0, or /dev/ttyUSB0
        ser = serial.Serial(port, baudrate, timeout=1)
        print(f"[SUCCESS] XBee initialized on {port} at {baudrate} baud.")
        return ser
    except Exception as e:
        print(f"[ERROR] XBee initialization failed on {port}: {e}")
        return None

def initialize_camera(camera_index=0):
    """Initialize the camera."""
    cap = cv2.VideoCapture(camera_index)
    if cap.isOpened():
        print(f"[SUCCESS] Camera initialized (Index {camera_index}).")
        return cap
    else:
        print(f"[ERROR] Could not open camera (Index {camera_index}).")
        return None

def main():
    print("Starting System Test...")
    
    # 1. Setup Sensors
    bmp, lsm = initialize_sensors()
    
    # 2. Setup XBee
    # Try typical ports if the default fails, or just stick to one for now.
    # Users often use /dev/ttyUSB0 if using a USB explorer, or /dev/serial0 for GPIO pins.
    xbee = initialize_xbee('/dev/serial0') 
    
    # 3. Setup Camera
    cap = initialize_camera()

    print("\nStarting Loop. Press 'q' in the camera window or Ctrl+C to exit.\n")
    
    try:
        while True:
            # --- Sensor Readings ---
            sensor_text = "Sensors: N/A"
            if bmp and lsm:
                try:
                    alt = bmp.altitude
                    pres = bmp.pressure
                    acc_x, acc_y, acc_z = lsm.acceleration
                    
                    # Log to console (on one line)
                    status_msg = (f"Alt: {alt:6.2f}m | Pres: {pres:7.2f}hPa | "
                                  f"Acc: {acc_x:5.2f}, {acc_y:5.2f}, {acc_z:5.2f}")
                    print(status_msg, end="\r")
                    
                    sensor_text = f"Alt: {alt:.1f}m Acc: {acc_x:.1f},{acc_y:.1f},{acc_z:.1f}"
                    
                except Exception as e:
                    print(f"\n[ERROR] Reading sensors: {e}")

            # --- XBee Communication ---
            if xbee:
                try:
                    # Write data to XBee
                    if bmp and lsm:
                        # Send a formatted string over radio
                        packet = f"{status_msg}\n".encode('utf-8')
                        xbee.write(packet)
                    
                    # Read incoming data (if any)
                    if xbee.in_waiting > 0:
                        incoming = xbee.readline().decode('utf-8', errors='ignore').strip()
                        if incoming:
                            print(f"\n[XBEE RX] {incoming}")
                except Exception as e:
                    print(f"\n[ERROR] XBee error: {e}")

            # --- Camera Feed ---
            if cap:
                ret, frame = cap.read()
                if ret:
                    # Overlay sensor data on the frame
                    cv2.putText(frame, sensor_text, (10, 30), 
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                    
                    # Check XBee status for overlay
                    xbee_status = "XBee: OK" if xbee else "XBee: ERR"
                    cv2.putText(frame, xbee_status, (10, 60), 
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)

                    cv2.imshow('System Test Feed', frame)
                    
                    # Press 'q' to quit
                    if cv2.waitKey(1) & 0xFF == ord('q'):
                        print("\n'q' pressed. Exiting...")
                        break
                else:
                    print("\n[WARN] Failed to read frame.")
            
            # Reduce CPU usage slightly
            # time.sleep(0.05) # cv2.waitKey handles timing well enough usually

    except KeyboardInterrupt:
        print("\nStopped by user.")
    finally:
        # Cleanup
        if cap: cap.release()
        cv2.destroyAllWindows()
        if xbee: xbee.close()
        print("Cleanup complete.")

if __name__ == "__main__":
    main()
