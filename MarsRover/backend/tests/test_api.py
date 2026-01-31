import pytest
from httpx import AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_sensors_endpoint():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        r = await ac.get("/api/sensors")
        assert r.status_code == 200
        data = r.json()
        assert "imu" in data
        assert "barometer" in data
