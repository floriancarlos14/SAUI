import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import imageio_ffmpeg
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from starlette.background import BackgroundTask

# Bundle ffmpeg so librosa/audioread can decode MP3, M4A, FLAC and OGG on Windows.
_ffmpeg_dir = str(Path(imageio_ffmpeg.get_ffmpeg_exe()).parent)
os.environ["PATH"] = _ffmpeg_dir + os.pathsep + os.environ.get("PATH", "")

app = FastAPI(title="SAUI Conversion API", version="0.3.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("SAUI_ALLOWED_ORIGINS", "*").split(","),
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

MAX_FILE_BYTES = 100 * 1024 * 1024
ALLOWED_EXTENSIONS = {".wav", ".mp3", ".m4a", ".flac", ".ogg"}
SEED_VC_DIR = Path(os.getenv("SEED_VC_DIR", "/opt/seed-vc"))


@app.get("/health")
async def health():
    inference_script = SEED_VC_DIR / "inference.py"
    return {
        "service": "SAUI",
        "status": "online",
        "inference_ready": inference_script.is_file(),
        "engine": "Seed-VC singing voice conversion",
        "device_mode": "cuda" if os.getenv("SAUI_FP16", "False").lower() == "true" else "cpu",
        "message": (
            "Seed-VC inference script found."
            if inference_script.is_file()
            else "API is online, but Seed-VC is not installed at SEED_VC_DIR."
        ),
    }


async def save_audio(upload: UploadFile, label: str, destination: Path) -> None:
    suffix = Path(upload.filename or "").suffix.lower()
    if suffix not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=415, detail=f"{label}: unsupported audio format.")
    data = await upload.read(MAX_FILE_BYTES + 1)
    if len(data) > MAX_FILE_BYTES:
        raise HTTPException(status_code=413, detail=f"{label}: file exceeds 100 MB.")
    if not data:
        raise HTTPException(status_code=400, detail=f"{label}: empty file.")
    destination.write_bytes(data)


@app.post("/convert")
async def convert(
    song: UploadFile = File(...),
    voice_reference: UploadFile = File(...),
    pitch_shift: int = Form(0),
    strength: float = Form(0.7),
):
    if not -12 <= pitch_shift <= 12:
        raise HTTPException(status_code=422, detail="pitch_shift must be between -12 and 12.")
    if not 0 <= strength <= 1:
        raise HTTPException(status_code=422, detail="strength must be between 0 and 1.")

    inference_script = SEED_VC_DIR / "inference.py"
    if not inference_script.is_file():
        raise HTTPException(status_code=503, detail="Seed-VC runtime is not installed. Run the Windows setup launcher first.")

    workdir = Path(tempfile.mkdtemp(prefix="saui-"))
    source_path = workdir / f"source{Path(song.filename or 'song.wav').suffix.lower()}"
    reference_path = workdir / f"reference{Path(voice_reference.filename or 'voice.wav').suffix.lower()}"
    output_dir = workdir / "output"
    output_dir.mkdir()

    try:
        await save_audio(song, "Song", source_path)
        await save_audio(voice_reference, "Voice reference", reference_path)
        command = [
            os.getenv("PYTHON_EXECUTABLE", "python"), str(inference_script),
            "--source", str(source_path), "--target", str(reference_path),
            "--output", str(output_dir),
            "--diffusion-steps", os.getenv("SAUI_DIFFUSION_STEPS", "8"),
            "--length-adjust", "1.0",
            "--inference-cfg-rate", str(strength),
            "--f0-condition", "True", "--auto-f0-adjust", "False",
            "--semi-tone-shift", str(pitch_shift),
            "--fp16", os.getenv("SAUI_FP16", "False"),
        ]
        try:
            completed = subprocess.run(
                command, cwd=str(SEED_VC_DIR), capture_output=True,
                text=True, timeout=int(os.getenv("SAUI_CONVERSION_TIMEOUT", "7200")),
                check=False,
            )
        except subprocess.TimeoutExpired:
            raise HTTPException(status_code=504, detail="Conversion timed out. Try a shorter audio clip.")

        if completed.returncode != 0:
            tail = (completed.stderr or completed.stdout or "Unknown model error")[-4000:]
            raise HTTPException(status_code=500, detail=f"Seed-VC failed: {tail}")
        outputs = sorted(output_dir.glob("vc_*.wav"))
        if not outputs:
            raise HTTPException(status_code=500, detail="The model finished but did not produce a WAV file.")
        return FileResponse(
            path=outputs[0], media_type="audio/wav", filename="saui_converted.wav",
            background=BackgroundTask(shutil.rmtree, workdir, ignore_errors=True),
        )
    except Exception:
        shutil.rmtree(workdir, ignore_errors=True)
        raise
