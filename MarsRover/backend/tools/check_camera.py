#!/usr/bin/env python3
"""Minimal camera diagnostic helper for libcamera / Picamera2

Usage:
  python backend/tools/check_camera.py

This script checks for libcamera and Picamera2 availability and attempts a basic capture.
"""
import subprocess
import sys
import shutil


def run(cmd):
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, shell=True, text=True)
        return out
    except subprocess.CalledProcessError as e:
        return e.output


def main():
    print('Checking libcamera-hello...')
    if shutil.which('libcamera-hello'):
        print(run('libcamera-hello --list-cameras || true'))
    else:
        print('libcamera-hello not found in PATH')

    print('\nChecking /dev/video*')
    print(run('ls -l /dev/video* 2>/dev/null || true'))

    print('\nTrying Picamera2 import and a quick capture...')
    try:
        from picamera2 import Picamera2
        pc = Picamera2()
        print('Picamera2 import OK')
        try:
            config = pc.create_preview_configuration({'main': {'format':'RGB888'}})
            pc.configure(config)
            pc.start()
            arr = pc.capture_array()
            print('Captured array shape:', getattr(arr, 'shape', 'unknown'))
            pc.stop()
            print('Capture OK')
        except Exception as e:
            print('Picamera2 capture failed:', e)
    except Exception as e:
        print('Picamera2 import failed:', e)
        print("Try: sudo apt install libcamera-apps && pip install 'picamera2>=0.3.30,<0.4'")

if __name__ == '__main__':
    main()
