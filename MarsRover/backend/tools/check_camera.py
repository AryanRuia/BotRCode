#!/usr/bin/env python3
"""Minimal camera diagnostic helper for libcamera / Picamera2

Usage:
  python backend/tools/check_camera.py

This script checks for libcamera and Picamera2 availability and attempts a basic capture.
"""
import subprocess
import sys
import shutil
import os


def run(cmd):
    try:
        proc = subprocess.run(cmd, stderr=subprocess.STDOUT, shell=True, text=True, capture_output=True, timeout=8)
        return proc.stdout
    except subprocess.TimeoutExpired as e:
        return f"TIMEOUT after {e.timeout}s\n{getattr(e, 'output', '') or ''}"
    except subprocess.CalledProcessError as e:
        return e.output


def main():
    print('Checking libcamera-hello...')
    if shutil.which('libcamera-hello'):
        print(run('libcamera-hello --list-cameras || true'))
    else:
        print('libcamera-hello not found in PATH')
        # Check for Arducam rpicam utilities (IMX519 often uses them)
        if shutil.which('rpicam-still'):
            print('\nFound Arducam rpicam tools. Listing cameras via rpicam-still:')
            print(run('rpicam-still --list-cameras || true'))
        else:
            print('rpicam-still not found in PATH')

    print('\nChecking /dev/video*')
    video_out = run('ls -l /dev/video* 2>/dev/null || true')
    print(video_out)

    # Check whether the current user is in the video group (needed to read /dev/video*)
    import getpass, grp
    user = getpass.getuser()
    try:
        video_gid = grp.getgrnam('video').gr_gid
        in_video = any('video' in g.gr_name for g in grp.getgrall() if user in g.gr_mem)
    except KeyError:
        in_video = False
    if not in_video:
        print('\nNOTE: your user may not be in the "video" group; add it with:')
        print(f"  sudo usermod -aG video {user} && newgrp video")

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
        print('\nIf you see cameras via `rpicam-still --list-cameras` (Arducam) you can try a quick capture with Arducam tools:')
        if shutil.which('rpicam-still'):
            print('Attempting a quick capture with rpicam-still to /tmp/marsrover-test.jpg (try safe modes)...')
            candidates = [
                'rpicam-still --camera 0 --output /tmp/marsrover-test.jpg',
                'rpicam-still --camera 0 --output /tmp/marsrover-test.jpg --width 1920 --height 1080',
                'rpicam-still --camera 0 --output /tmp/marsrover-test.jpg --mode 1920x1080',
            ]
            out = ''
            for cmd in candidates:
                out = run(cmd + ' || true')
                print('Tried:', cmd)
                print(out)
                if os.path.exists('/tmp/marsrover-test.jpg'):
                    print('Arducam capture succeeded: /tmp/marsrover-test.jpg')
                    try:
                        os.remove('/tmp/marsrover-test.jpg')
                    except Exception:
                        pass
                    break
                # continue to next candidate
            else:
                print('Arducam capture did not produce a file; check rpicam-still options and drivers.')
        else:
            print('No rpicam-still tool found to attempt a capture.')

        print('\nTo enable Picamera2 integration (recommended):')
        print('  # activate venv first (if using the project venv)')
        print('  source backend/venv/bin/activate')
        print("  pip install 'picamera2>=0.3.30,<0.4'")
        print('\nIf libcamera tools are missing, install system package:')
        print('  sudo apt install libcamera-apps')
        print('\nAfter installing drivers/tools, verify with:')
        print('  libcamera-hello --list-cameras')
        print('  rpicam-still --list-cameras')



if __name__ == '__main__':
    main()
