import os
import time
from typing import Dict

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

SERVICE_NAME = os.getenv("SERVICE_NAME", "container-reference")
SERVICE_VERSION = os.getenv("SERVICE_VERSION", "1.0.0")
STARTED_AT = time.time()

app = FastAPI(title=SERVICE_NAME, version=SERVICE_VERSION)


class ConversionRequest(BaseModel):
    value: float = Field(..., ge=-1000.0, le=10000.0)
    unit: str = Field(..., min_length=1, max_length=8)


class ConversionResponse(BaseModel):
    value: float
    unit: str
    converted: float
    converted_unit: str


@app.get("/healthz")
def healthz() -> Dict[str, str]:
    return {"status": "ok", "service": SERVICE_NAME, "version": SERVICE_VERSION}


@app.get("/readyz")
def readyz() -> Dict[str, object]:
    return {"ready": True, "uptime_seconds": round(time.time() - STARTED_AT, 3)}


@app.post("/v1/convert", response_model=ConversionResponse)
def convert(payload: ConversionRequest) -> ConversionResponse:
    unit = payload.unit.strip().lower()
    if unit == "c":
        return ConversionResponse(
            value=payload.value,
            unit="C",
            converted=round(payload.value * 9.0 / 5.0 + 32.0, 4),
            converted_unit="F",
        )
    if unit == "f":
        return ConversionResponse(
            value=payload.value,
            unit="F",
            converted=round((payload.value - 32.0) * 5.0 / 9.0, 4),
            converted_unit="C",
        )
    raise HTTPException(status_code=422, detail="unsupported unit")
