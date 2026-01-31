"""Camera wrapper using Picamera2; returns JPEG bytes or None on failure"""

try:
    from picamera2 import Picamera2
    from libcamera import Transform
    hw = True
except Exception:
    hw = False

_camera = None


def _ensure_camera():
    global _camera
    if not hw:
        return None
    if _camera is None:
        pc2 = Picamera2()
        camera_config = pc2.create_still_configuration(main={'format':'RGB888'})
        pc2.configure(camera_config)
        pc2.start()
        _camera = pc2
    return _camera


def capture_jpeg():
    cam = _ensure_camera()
    if cam is None:
        return None
    try:
        im = cam.capture_array()
        # Encode via OpenCV if installed
        try:
            import cv2
            ret, buf = cv2.imencode('.jpg', im)
            if ret:
                return buf.tobytes()
        except Exception:
            # Fallback: attempt to use PIL
            try:
                from PIL import Image
                import io
                img = Image.fromarray(im)
                buf = io.BytesIO()
                img.save(buf, format='JPEG')
                return buf.getvalue()
            except Exception:
                return None
    except Exception:
        return None
