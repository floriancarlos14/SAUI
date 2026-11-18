"""SAUI community music API: accounts, uploads, playback, likes, comments and playlists.

Local MVP storage uses SQLite and a media/ directory. Set SAUI_DATA_DIR to persist data.
"""
import hashlib
import hmac
import os
import re
import secrets
import sqlite3
import time
import uuid
from pathlib import Path
from contextlib import contextmanager
from typing import Optional

from fastapi import APIRouter, Depends, File, Header, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api", tags=["SAUI Music Platform"])
DATA_DIR = Path(os.getenv("SAUI_DATA_DIR", str(Path(__file__).resolve().parents[1] / "data")))
MEDIA_DIR = DATA_DIR / "media"
DB_PATH = DATA_DIR / "saui.sqlite3"
MAX_TRACK_BYTES = 50 * 1024 * 1024
ALLOWED_AUDIO = {".mp3", ".wav", ".m4a", ".flac", ".ogg"}
TOKEN_SECRET = os.getenv("SAUI_TOKEN_SECRET", "development-only-change-this-secret").encode()


@contextmanager
def db():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    MEDIA_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys=ON")
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_db():
    with db() as c:
        c.executescript("""
        CREATE TABLE IF NOT EXISTS users(
          id TEXT PRIMARY KEY, username TEXT UNIQUE NOT NULL, email TEXT UNIQUE NOT NULL,
          password_hash TEXT NOT NULL, created_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS tracks(
          id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id),
          title TEXT NOT NULL, artist TEXT NOT NULL, genre TEXT NOT NULL DEFAULT '',
          description TEXT NOT NULL DEFAULT '', filename TEXT NOT NULL,
          original_name TEXT NOT NULL, created_at INTEGER NOT NULL,
          plays INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS likes(
          user_id TEXT NOT NULL REFERENCES users(id), track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
          created_at INTEGER NOT NULL, PRIMARY KEY(user_id, track_id)
        );
        CREATE TABLE IF NOT EXISTS comments(
          id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id),
          track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
          body TEXT NOT NULL, created_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS follows(
          follower_id TEXT NOT NULL REFERENCES users(id), followed_id TEXT NOT NULL REFERENCES users(id),
          created_at INTEGER NOT NULL, PRIMARY KEY(follower_id, followed_id),
          CHECK(follower_id <> followed_id)
        );
        CREATE TABLE IF NOT EXISTS playlists(
          id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id),
          title TEXT NOT NULL, created_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS playlist_tracks(
          playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
          track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
          position INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(playlist_id, track_id)
        );
        """)


init_db()


def password_hash(password: str, salt: Optional[bytes] = None) -> str:
    salt = salt or secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 240000)
    return salt.hex() + ":" + digest.hex()


def verify_password(password: str, stored: str) -> bool:
    try:
        salt_hex, digest_hex = stored.split(":", 1)
        return hmac.compare_digest(password_hash(password, bytes.fromhex(salt_hex)).split(":", 1)[1], digest_hex)
    except (ValueError, TypeError):
        return False


def make_token(user_id: str) -> str:
    expiry = str(int(time.time()) + 60 * 60 * 24 * 30)
    payload = f"{user_id}.{expiry}"
    sig = hmac.new(TOKEN_SECRET, payload.encode(), hashlib.sha256).hexdigest()
    return f"{payload}.{sig}"


def current_user(authorization: Optional[str] = Header(default=None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Sign in is required.")
    try:
        user_id, expiry, sig = authorization[7:].split(".", 2)
        payload = f"{user_id}.{expiry}"
        expected = hmac.new(TOKEN_SECRET, payload.encode(), hashlib.sha256).hexdigest()
        if int(expiry) < int(time.time()) or not hmac.compare_digest(sig, expected):
            raise ValueError()
    except (ValueError, TypeError):
        raise HTTPException(401, "Session expired. Please sign in again.")
    with db() as c:
        user = c.execute("SELECT id, username, email, created_at FROM users WHERE id=?", (user_id,)).fetchone()
    if not user:
        raise HTTPException(401, "Account not found.")
    return dict(user)


class RegisterBody(BaseModel):
    username: str = Field(min_length=3, max_length=24)
    email: str = Field(min_length=5, max_length=254)
    password: str = Field(min_length=10, max_length=128)


class LoginBody(BaseModel):
    email: str
    password: str


class TrackBody(BaseModel):
    title: str = Field(min_length=1, max_length=100)
    genre: str = Field(default="", max_length=40)
    description: str = Field(default="", max_length=1000)


class CommentBody(BaseModel):
    body: str = Field(min_length=1, max_length=1000)


class PlaylistBody(BaseModel):
    title: str = Field(min_length=1, max_length=80)


def track_json(row):
    return {k: row[k] for k in row.keys()}


@router.get("/health")
def platform_health():
    return {"platform": "SAUI", "status": "online", "storage": "local SQLite + media folder"}


@router.post("/auth/register")
def register(body: RegisterBody):
    email = body.email.strip().lower()
    if not re.fullmatch(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", email):
        raise HTTPException(422, "Enter a valid email address.")
    if not re.fullmatch(r"[A-Za-z0-9_]{3,24}", body.username):
        raise HTTPException(422, "Username must be 3 to 24 letters, numbers or underscores.")
    user_id, now = str(uuid.uuid4()), int(time.time())
    try:
        with db() as c:
            c.execute("INSERT INTO users VALUES(?,?,?,?,?)",
                      (user_id, body.username, email, password_hash(body.password), now))
    except sqlite3.IntegrityError:
        raise HTTPException(409, "That username or email is already registered.")
    user = {"id": user_id, "username": body.username, "email": email, "created_at": now}
    return {"user": user, "access_token": make_token(user_id), "token_type": "bearer"}


@router.post("/auth/login")
def login(body: LoginBody):
    with db() as c:
        row = c.execute("SELECT * FROM users WHERE email=?", (body.email.strip().lower(),)).fetchone()
    if not row or not verify_password(body.password, row["password_hash"]):
        raise HTTPException(401, "Incorrect email or password.")
    return {"user": {"id": row["id"], "username": row["username"], "email": row["email"]},
            "access_token": make_token(row["id"]), "token_type": "bearer"}


@router.get("/me")
def me(user=Depends(current_user)):
    return user


@router.post("/tracks")
async def upload_track(title: str, genre: str = "", description: str = "",
                       audio: UploadFile = File(...), user=Depends(current_user)):
    suffix = Path(audio.filename or "").suffix.lower()
    if suffix not in ALLOWED_AUDIO:
        raise HTTPException(415, "Supported formats: MP3, WAV, M4A, FLAC and OGG.")
    data = await audio.read(MAX_TRACK_BYTES + 1)
    if not data:
        raise HTTPException(400, "The audio file is empty.")
    if len(data) > MAX_TRACK_BYTES:
        raise HTTPException(413, "Maximum upload size is 50 MB.")
    title = title.strip()
    if not title or len(title) > 100:
        raise HTTPException(422, "Track title must be 1 to 100 characters.")
    track_id, now = str(uuid.uuid4()), int(time.time())
    stored = track_id + suffix
    MEDIA_DIR.mkdir(parents=True, exist_ok=True)
    (MEDIA_DIR / stored).write_bytes(data)
    try:
        with db() as c:
            c.execute("""INSERT INTO tracks(id,user_id,title,artist,genre,description,filename,original_name,created_at)
                         VALUES(?,?,?,?,?,?,?,?,?)""",
                      (track_id, user["id"], title, user["username"], genre[:40], description[:1000],
                       stored, (audio.filename or stored)[:255], now))
    except Exception:
        (MEDIA_DIR / stored).unlink(missing_ok=True)
        raise
    return {"id": track_id, "title": title, "artist": user["username"], "genre": genre, "created_at": now}


@router.get("/tracks")
def list_tracks(q: str = "", limit: int = 30, offset: int = 0):
    limit = max(1, min(limit, 100)); offset = max(0, offset)
    term = f"%{q.strip()}%"
    with db() as c:
        rows = c.execute("""SELECT t.id,t.user_id,t.title,t.artist,t.genre,t.description,t.created_at,t.plays,
          (SELECT COUNT(*) FROM likes l WHERE l.track_id=t.id) AS likes
          FROM tracks t WHERE t.title LIKE ? OR t.artist LIKE ? OR t.genre LIKE ?
          ORDER BY t.created_at DESC LIMIT ? OFFSET ?""", (term, term, term, limit, offset)).fetchall()
    return {"items": [track_json(r) for r in rows], "limit": limit, "offset": offset}


@router.get("/tracks/{track_id}")
def track_detail(track_id: str):
    with db() as c:
        row = c.execute("""SELECT t.id,t.user_id,t.title,t.artist,t.genre,t.description,t.created_at,t.plays,
          (SELECT COUNT(*) FROM likes l WHERE l.track_id=t.id) AS likes
          FROM tracks t WHERE t.id=?""", (track_id,)).fetchone()
    if not row:
        raise HTTPException(404, "Track not found.")
    return track_json(row)


@router.get("/tracks/{track_id}/audio")
def stream_track(track_id: str):
    with db() as c:
        row = c.execute("SELECT filename,original_name FROM tracks WHERE id=?", (track_id,)).fetchone()
        if not row:
            raise HTTPException(404, "Track not found.")
        c.execute("UPDATE tracks SET plays=plays+1 WHERE id=?", (track_id,))
    path = MEDIA_DIR / row["filename"]
    if not path.is_file():
        raise HTTPException(404, "Audio file is missing from storage.")
    return FileResponse(path, filename=row["original_name"], media_type="application/octet-stream")


@router.post("/tracks/{track_id}/like")
def toggle_like(track_id: str, user=Depends(current_user)):
    with db() as c:
        if not c.execute("SELECT 1 FROM tracks WHERE id=?", (track_id,)).fetchone():
            raise HTTPException(404, "Track not found.")
        exists = c.execute("SELECT 1 FROM likes WHERE user_id=? AND track_id=?", (user["id"], track_id)).fetchone()
        if exists:
            c.execute("DELETE FROM likes WHERE user_id=? AND track_id=?", (user["id"], track_id))
            liked = False
        else:
            c.execute("INSERT INTO likes VALUES(?,?,?)", (user["id"], track_id, int(time.time())))
            liked = True
    return {"liked": liked}


@router.get("/tracks/{track_id}/comments")
def list_comments(track_id: str):
    with db() as c:
        rows = c.execute("""SELECT comments.id,comments.body,comments.created_at,users.username
          FROM comments JOIN users ON users.id=comments.user_id
          WHERE comments.track_id=? ORDER BY comments.created_at DESC LIMIT 100""", (track_id,)).fetchall()
    return [dict(r) for r in rows]


@router.post("/tracks/{track_id}/comments")
def add_comment(track_id: str, body: CommentBody, user=Depends(current_user)):
    comment_id = str(uuid.uuid4())
    with db() as c:
        if not c.execute("SELECT 1 FROM tracks WHERE id=?", (track_id,)).fetchone():
            raise HTTPException(404, "Track not found.")
        c.execute("INSERT INTO comments VALUES(?,?,?,?,?)",
                  (comment_id, user["id"], track_id, body.body.strip(), int(time.time())))
    return {"id": comment_id, "username": user["username"], "body": body.body.strip()}


@router.post("/users/{creator_id}/follow")
def toggle_follow(creator_id: str, user=Depends(current_user)):
    if creator_id == user["id"]:
        raise HTTPException(400, "You cannot follow your own profile.")
    with db() as c:
        if not c.execute("SELECT 1 FROM users WHERE id=?", (creator_id,)).fetchone():
            raise HTTPException(404, "Creator not found.")
        exists = c.execute("SELECT 1 FROM follows WHERE follower_id=? AND followed_id=?", (user["id"], creator_id)).fetchone()
        if exists:
            c.execute("DELETE FROM follows WHERE follower_id=? AND followed_id=?", (user["id"], creator_id))
            following = False
        else:
            c.execute("INSERT INTO follows VALUES(?,?,?)", (user["id"], creator_id, int(time.time())))
            following = True
    return {"following": following}


@router.post("/playlists")
def create_playlist(body: PlaylistBody, user=Depends(current_user)):
    playlist_id = str(uuid.uuid4())
    with db() as c:
        c.execute("INSERT INTO playlists VALUES(?,?,?,?)", (playlist_id, user["id"], body.title.strip(), int(time.time())))
    return {"id": playlist_id, "title": body.title.strip()}


@router.get("/playlists")
def list_playlists(user=Depends(current_user)):
    with db() as c:
        rows = c.execute("""SELECT p.id,p.title,p.created_at,COUNT(pt.track_id) AS track_count
          FROM playlists p LEFT JOIN playlist_tracks pt ON pt.playlist_id=p.id
          WHERE p.user_id=? GROUP BY p.id ORDER BY p.created_at DESC""", (user["id"],)).fetchall()
    return [dict(r) for r in rows]


@router.post("/playlists/{playlist_id}/tracks/{track_id}")
def add_to_playlist(playlist_id: str, track_id: str, user=Depends(current_user)):
    with db() as c:
        if not c.execute("SELECT 1 FROM playlists WHERE id=? AND user_id=?", (playlist_id, user["id"])).fetchone():
            raise HTTPException(404, "Playlist not found.")
        if not c.execute("SELECT 1 FROM tracks WHERE id=?", (track_id,)).fetchone():
            raise HTTPException(404, "Track not found.")
        c.execute("INSERT OR IGNORE INTO playlist_tracks(playlist_id,track_id) VALUES(?,?)", (playlist_id, track_id))
    return {"added": True}


@router.get("/playlists/{playlist_id}/tracks")
def playlist_tracks(playlist_id: str, user=Depends(current_user)):
    with db() as c:
        if not c.execute("SELECT 1 FROM playlists WHERE id=? AND user_id=?", (playlist_id, user["id"])).fetchone():
            raise HTTPException(404, "Playlist not found.")
        rows = c.execute("""SELECT t.id,t.title,t.artist,t.genre,t.plays FROM playlist_tracks pt
          JOIN tracks t ON t.id=pt.track_id WHERE pt.playlist_id=? ORDER BY pt.position,t.created_at DESC""", (playlist_id,)).fetchall()
    return [dict(r) for r in rows]


@router.get("/creator/dashboard")
def creator_dashboard(user=Depends(current_user)):
    with db() as c:
        totals = c.execute("""SELECT COUNT(*) AS tracks, COALESCE(SUM(plays),0) AS plays
          FROM tracks WHERE user_id=?""", (user["id"],)).fetchone()
        likes = c.execute("""SELECT COUNT(*) AS total FROM likes
          JOIN tracks ON tracks.id=likes.track_id WHERE tracks.user_id=?""", (user["id"],)).fetchone()["total"]
        followers = c.execute("SELECT COUNT(*) AS total FROM follows WHERE followed_id=?", (user["id"],)).fetchone()["total"]
        recent = c.execute("""SELECT id,title,plays,created_at FROM tracks
          WHERE user_id=? ORDER BY created_at DESC LIMIT 10""", (user["id"],)).fetchall()
    return {"tracks": totals["tracks"], "plays": totals["plays"], "likes": likes,
            "followers": followers, "recent_tracks": [dict(r) for r in recent],
            "earnings_status": "not_enabled",
            "earnings_message": "Creator payouts are not enabled yet. No stream earnings are currently calculated."}
