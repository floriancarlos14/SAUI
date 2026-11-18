# SAUI — Singing Voice Conversion

SAUI is an open-source starter project for singing voice conversion. The Flutter app provides audio upload, conversion settings, preview, and export. A FastAPI service defines the backend contract.

## Current status
- Flutter interface and upload workflow: included.
- Backend API contract and validation: included.
- AI model inference: **not yet integrated or tested**. A compatible model runtime and GPU-capable host are required before conversion can work.
- No per-conversion payment is built into this project.

## Project layout
- `app/`: Flutter client
- `backend/`: FastAPI service

## Run the backend locally
```bash
cd backend
python -m venv .venv
# Activate the environment, then:
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Run the Flutter app
Install Flutter, then:
```bash
cd app
flutter pub get
flutter run -d chrome
```

Set the backend URL in the app before testing against a deployed service. The default is `http://localhost:8000`.

## Important
This repository does not include model weights. Do not upload voice samples you do not have permission to use. Before public deployment, configure storage limits, authentication, abuse prevention, and a GPU runtime.
