"""Simple XBee serial wrapper. Configure SERIAL_PORT and SERIAL_BAUD via env vars."""
import os
import time

try:
    import serial
    hw = True
except Exception:
    hw = False

SERIAL_PORT = os.getenv('SERIAL_PORT', '/dev/serial0')
SERIAL_BAUD = int(os.getenv('SERIAL_BAUD', 9600))


def send_command(cmd: str, timeout: float = 2.0) -> bool:
    """Send a simple text command over serial to XBee. Returns True on success."""
    if not hw:
        # Emulate send
        print(f"[xbee-emulator] send: {cmd}")
        return True
    try:
        with serial.Serial(SERIAL_PORT, SERIAL_BAUD, timeout=timeout) as ser:
            ser.write(cmd.encode('utf-8') + b"\n")
            # Optionally read a response
            time.sleep(0.1)
            if ser.in_waiting:
                resp = ser.read(ser.in_waiting)
                print("xbee resp:", resp)
        return True
    except Exception as e:
        print("XBee send error:", e)
        return False
