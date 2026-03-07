from flask import Flask, render_template, jsonify
import serial
import threading

app = Flask(__name__)
# Shared data between XBee thread and Flask
telemetry = {"temp": 0, "pressure": 0, "accel": [0, 0, 0]}

ser = serial.Serial('/dev/ttyAMA0', 9600, timeout=1)

def listen_xbee():
    global telemetry
    while True:
        if ser.in_waiting > 0:
            try:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                parts = line.split('|')
                d = {}
                for p in parts:
                    k, v = p.split(':')
                    d[k] = float(v)
                telemetry = {
                    "temp": d.get("T", 0),
                    "pressure": d.get("P", 0),
                    "accel": [d.get("AX", 0), d.get("AY", 0), d.get("AZ", 0)]
                }
            except: pass

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/status')
def status():
    return jsonify({
        "status": "XBee Linked",
        "telemetry": telemetry,
        "camera": "WiFi",
        "resolution": [1280, 720],
        "fps": 30
    })

if __name__ == '__main__':
    threading.Thread(target=listen_xbee, daemon=True).start()
    app.run(host='0.0.0.0', port=8080)