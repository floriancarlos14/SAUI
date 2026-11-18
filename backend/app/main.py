from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="SAUI Conversion API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict this to the deployed app domain before public launch.
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

MAX_FILE_BYTES = 30 * 1024 * 1024
ALLOWED_EXTENSIONS = {".wav", ".mp3", ".m4a", ".flac", ".ogg"}


@app.get("/health")
async def health():
    return {
        "service": "SAUI",
        "status": "online",
        "inference_ready": False,
        "message": "API is running; AI model runtime is not configured yet.",
    }


async def validate_audio(upload: UploadFile, label: str) -> bytes:
    filename = (upload.filename or "").lower()
    if not any(filename.endswith(ext) for ext in ALLOWED_EXTENSIONS):
        raise HTTPException(status_code=415, detail=f"{label}: unsupported audio format.")
    data = await upload.read(MAX_FILE_BYTES + 1)
    if len(data) > MAX_FILE_BYTES:
        raise HTTPException(status_code=413, detail=f"{label}: file exceeds 30 MB.")
    if not data:
        raise HTTPException(status_code=400, detail=f"{label}: empty file.")
    return data


@app.post("/convert")
async def convert(
    song: UploadFile = File(...),
    voice_reference: UploadFile = File(...),
    pitch_shift: int = Form(0),
    strength: float = Form(0.7),
):
    if pitch_shift < -12 or pitch_shift > 12:
        raise HTTPException(status_code=422, detail="pitch_shift must be between -12 and 12.")
    if strength < 0 or strength > 1:
        raise HTTPException(status_code=422, detail="strength must be between 0 and 1.")

    # Validate both uploads now. Model inference is intentionally not faked:
    # connect a licensed, compatible singing-voice model runtime before enabling conversion.
    await validate_audio(song, "Song")
    await validate_audio(voice_reference, "Voice reference")

    raise HTTPException(
        status_code=503,
        detail=(
            "SAUI upload API is ready, but the AI conversion model is not installed. "
            "A compatible model runtime and GPU host must be configured before conversion."
        ),
    )
