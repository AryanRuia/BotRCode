from fastapi import FastAPI, WebSocket, UploadFile, File, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import asyncio
import os
import io
from drivers import lsm6dsox, bmp388, camera, xbee
from dotenv import load_dotenv

load_dotenv()
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", 8000))

app = FastAPI(title="MarsRover Backend")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve static frontend built files
static_dir = os.path.join(os.path.dirname(__file__), '..', 'static')
if os.path.isdir(static_dir):
    app.mount("/", StaticFiles(directory=static_dir, html=True), name="static")

# In-memory list of connected WebSocket clients
clients = set()

@app.on_event("startup")
async def startup_tasks():
    app.state._telemetry_task = asyncio.create_task(telemetry_broadcaster())

@app.on_event("shutdown")
async def shutdown_tasks():
    app.state._telemetry_task.cancel()
    for c in clients:
        await c.close()

async def telemetry_broadcaster():
    # Periodically read sensors and send telemetry to connected websocket clients
    while True:
        data = {
            "imu": lsm6dsox.read_imu(),
            "barometer": bmp388.read_pressure_temp(),
        }
        for ws in list(clients):
            try:
                await ws.send_json({"type": "telemetry", "payload": data})
            except Exception:
                try:
                    await ws.close()
                except Exception:
                    pass
                clients.discard(ws)
        await asyncio.sleep(1.0)

@app.get("/api/sensors")
async def get_sensors():
    try:
        imu = lsm6dsox.read_imu()
        baro = bmp388.read_pressure_temp()
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})
    return {"imu": imu, "barometer": baro}

@app.get("/api/camera/snapshot")
async def get_snapshot():
    image_bytes = camera.capture_jpeg()
    if image_bytes is None:
        raise HTTPException(status_code=500, detail="Camera capture failed")
    return StreamingResponse(io.BytesIO(image_bytes), media_type="image/jpeg")

@app.post("/api/xbee/send")
async def send_xbee(payload: dict):
    cmd = payload.get("command")
    if not cmd:
        raise HTTPException(status_code=400, detail="No command provided")
    ok = xbee.send_command(cmd)
    return {"ok": ok}

@app.websocket('/ws/telemetry')
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    clients.add(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # Allow clients to send ping or commands; echo for now
            await websocket.send_text(f"echo: {data}")
    except Exception:
        pass
    finally:
        clients.discard(websocket)
