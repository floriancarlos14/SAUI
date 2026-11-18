# SAUI — Singing Voice Conversion

SAUI is an open-source singing voice conversion app. The Flutter client accepts a song and a permitted voice reference; the FastAPI backend runs the Seed-VC singing-voice model and returns a WAV file.

## Included

- Flutter interface for selecting the song and voice reference.
- FastAPI `/convert` endpoint with upload validation.
- Windows CPU setup launcher (`backend/start-local-windows.bat`).
- Bundled ffmpeg dependency for MP3/M4A/FLAC/OGG decoding.
- Seed-VC F0-conditioned model output at 44.1 kHz.

## Run on Windows (no paid server or NVIDIA GPU required)

Requirements:
- Windows 10/11
- Python 3.10 with the Python Launcher (`py`)
- Git for Windows
- Internet for one-time downloads of packages and public model weights
- Several GB of free disk space

Steps:
1. Open the repository folder, then open `backend`.
2. Double-click `start-local-windows.bat`.
3. Wait for the first-time setup. It downloads Seed-VC, Python packages and model weights; this may take a while.
4. Keep the command window open. The local API address is `http://127.0.0.1:8000`.
5. Open the Flutter app on the same computer. Its default backend address is `http://localhost:8000`.
6. Upload a short song and a voice reference, then press **Convert**. The result is saved as WAV.

The launcher creates an isolated `.venv`, installs CPU-only PyTorch, prepares Seed-VC's transformer paths for FP32 CPU inference, and starts the API. If setup fails, the first error in the command window is the diagnostic. You can run the launcher again after correcting that error.

## Performance note

This is a local CPU compatibility path, not a fast conversion service. Seed-VC is a large neural model; on an older or low-memory computer, downloads and conversion can take a long time or run out of memory. A 2 GB legacy NVIDIA GPU is not suitable for the GPU Docker image. No paid server or per-conversion service is required for local use, but speed depends on the computer.

## Model and license

The conversion model is the third-party [Seed-VC project](https://github.com/Plachtaa/seed-vc), not a model trained by SAUI. Review its GPL-3.0 license and the licenses of downloaded model weights before redistributing SAUI. Use only voice recordings you have permission to use.

## Flutter web

From the repository's `app` directory:

```bash
flutter pub get
flutter run -d chrome
```

The default backend URL is `http://localhost:8000`. To use another backend, build with:

```bash
flutter build web --dart-define=SAUI_API_URL=http://127.0.0.1:8000
```
