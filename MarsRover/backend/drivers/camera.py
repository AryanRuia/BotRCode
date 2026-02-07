"""Camera wrapper: try Picamera2 first, then Arducam `rpicam-still` fallback.

Returns JPEG bytes on success or `None` on failure.
"""

import os
import shutil
import subprocess
import tempfile

_camera = None


def _ensure_camera():
    """Return an initialized Picamera2 instance or None if unavailable."""
    global _camera
    if _camera is not None:
        return _camera

    try:
        # import locally so missing libcamera doesn't break module import
        from picamera2 import Picamera2
    except Exception:
        return None

    try:
        pc2 = Picamera2()
        # prefer still configuration but fall back to preview if needed
        target_size = (2328, 1748)
        if hasattr(pc2, 'create_still_configuration'):
            try:
                cfg = pc2.create_still_configuration(main={'format': 'RGB888', 'size': target_size})
            except Exception:
                cfg = pc2.create_preview_configuration(main={'format': 'RGB888', 'size': target_size})
        else:
            cfg = pc2.create_preview_configuration(main={'format': 'RGB888', 'size': target_size})
        pc2.configure(cfg)
        pc2.start()
        _camera = pc2
        return _camera
    except Exception:
        return None


def _encode_image_to_jpeg_bytes(im):
    """Encode a numpy array image to JPEG bytes using cv2 or PIL."""
    try:
        import cv2
        ret, buf = cv2.imencode('.jpg', im)
        if ret:
            return buf.tobytes()
    except Exception:
        pass

    try:
        from PIL import Image
        import io
        img = Image.fromarray(im)
        buf = io.BytesIO()
        img.save(buf, format='JPEG')
        return buf.getvalue()
    except Exception:
        return None


def capture_jpeg():
    """Capture a JPEG from Picamera2 or fall back to rpicam-still.

    Returns bytes or None.
    """
    # Try Picamera2 first
    cam = _ensure_camera()
    if cam is not None:
        try:
            im = cam.capture_array()
            return _encode_image_to_jpeg_bytes(im)
        except Exception:
            # continue to fallback
            pass

    # Fallback: use Arducam rpicam-still if available
    if shutil.which('rpicam-still'):
        tmpfd, tmpname = tempfile.mkstemp(suffix='.jpg')
        os.close(tmpfd)
        try:
            candidates = [
                f'rpicam-still --camera 0 --output {tmpname}',
                f'rpicam-still --camera 0 --output {tmpname} --width 1920 --height 1080',
                f'rpicam-still --camera 0 --output {tmpname} --mode 1920x1080',
            ]
            for cmd in candidates:
                try:
                    proc = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=10)
                except subprocess.TimeoutExpired:
                    # command took too long; try next candidate
                    continue
                # if command returned quickly, check whether file was created
                if os.path.exists(tmpname):
                    with open(tmpname, 'rb') as f:
                        data = f.read()
                    return data
            # none produced a file
        finally:
            try:
                os.remove(tmpname)
            except Exception:
                pass

    return None
