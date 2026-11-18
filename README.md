# SAUI — AI Music Community & Streaming Platform

SAUI is being developed as a free-to-listen AI music community with optional Premium listening, creator profiles, music publishing, playlists, social features, and an AI Studio. The existing singing voice-conversion tool is one feature inside AI Studio, not the whole product.

## Current repository status

### Flutter app
- Spotify-inspired SAUI navigation shell: Home, Search, Your Library, Create, Profile.
- Sample discovery cards, sample tracks and a mini-player interface.
- AI Studio entry points for song upload, voice conversion and planned AI music generation.
- This Flutter screen is currently a UI prototype: sample tracks do not contain playable audio, and the Flutter app is not yet connected to the new community API.

### FastAPI community API (new MVP backend)
- Account registration and login with salted PBKDF2 password hashes and signed bearer sessions.
- Audio upload (MP3, WAV, M4A, FLAC, OGG; 50 MB per track).
- Public track catalog/search and audio-file streaming endpoint.
- Likes, comments, creator follows, playlists and playlist tracks.
- Creator dashboard metrics: track count, plays, likes and followers.
- SQLite database and local media-file storage.

## API routes

Base URL: `http://127.0.0.1:8000`

- `GET /health` — conversion service health
- `GET /api/health` — music platform health
- `POST /api/auth/register` — create account (JSON: username, email, password; password minimum 10 characters)
- `POST /api/auth/login` — sign in (JSON: email, password)
- `GET /api/me` — current account (Bearer token)
- `GET /api/tracks?q=&limit=30&offset=0` — browse/search tracks
- `POST /api/tracks?title=...&genre=...&description=...` — upload audio as multipart field `audio` (Bearer token)
- `GET /api/tracks/{track_id}` — track details
- `GET /api/tracks/{track_id}/audio` — stream uploaded audio
- `POST /api/tracks/{track_id}/like` — toggle like (Bearer token)
- `GET /api/tracks/{track_id}/comments` and `POST /api/tracks/{track_id}/comments` — comments
- `POST /api/users/{creator_id}/follow` — toggle follow (Bearer token)
- `POST /api/playlists` and `GET /api/playlists` — create/list personal playlists
- `POST /api/playlists/{playlist_id}/tracks/{track_id}` — add a track
- `GET /api/playlists/{playlist_id}/tracks` — list playlist tracks
- `GET /api/creator/dashboard` — creator metrics (Bearer token)

For protected routes, send `Authorization: Bearer <access_token>`.

## Run the local backend on Windows

The current launcher starts the conversion API and the new music platform API together.

Requirements:
- Windows 10/11
- Python 3.10 and Python Launcher (`py`)
- Git for Windows
- Internet for initial dependency/model downloads
- Free disk space for packages, model files, database and uploaded audio

1. Open the repository's `backend` folder.
2. Run `start-local-windows.bat`.
3. Keep the terminal open while using the local API.
4. Open `http://127.0.0.1:8000/docs` to inspect and test the API endpoints.

The API stores its SQLite database and uploaded tracks in `backend/data` by default. Set `SAUI_DATA_DIR` to a persistent writable directory before deployment. Set a long random `SAUI_TOKEN_SECRET` in the environment before using accounts beyond local testing. Do not expose the development default secret to the public internet.

## Important: what is not finished yet

This is an early backend MVP, not a finished Spotify-scale service. The Flutter client still needs to be connected to the API and real audio playback. The following are not implemented: hosted production database/object storage, moderation and copyright reporting, anti-fraud stream validation, advertisements, Premium billing, offline downloads, real creator revenue accounting, identity/tax checks and creator payouts. No one can currently earn money through SAUI, and the creator dashboard explicitly reports payouts as disabled.

Do not use this local SQLite/media-folder setup as a public production deployment. A public launch needs secure hosted infrastructure, backups, upload scanning, rate limits, content moderation, copyright/takedown procedures, privacy controls and payment-provider compliance.

## Voice conversion

The conversion feature remains available through the existing `POST /convert` endpoint and Seed-VC integration. It is a separate AI Studio feature. It requires the local model setup and has not been verified end-to-end on every target device.

## Model and content rights

Seed-VC is a third-party project. Review its GPL-3.0 license and the licenses of downloaded model weights before redistribution. Users must upload music and voice recordings they own or have permission to use. SAUI must implement rights reporting and moderation before public launch.
