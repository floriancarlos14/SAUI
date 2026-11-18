@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ==========================================
echo SAUI - Local Windows CPU Engine
echo ==========================================
echo This uses CPU mode and does not require an NVIDIA GPU or paid server.
echo First setup downloads Python packages and the Seed-VC code. Model weights download on first conversion.
echo Keep an internet connection and several GB of free disk space.
echo.

where py >nul 2>nul
if errorlevel 1 (
  echo ERROR: Python Launcher not found. Install Python 3.10 and enable "Add Python to PATH".
  echo Get Python from https://www.python.org/downloads/release/python-31011/
  pause
  exit /b 1
)

py -3.10 --version >nul 2>nul
if errorlevel 1 (
  echo ERROR: Python 3.10 is required. Install Python 3.10 first.
  pause
  exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
  echo [1/5] Creating isolated Python environment...
  py -3.10 -m venv .venv
  if errorlevel 1 goto failed
)

call ".venv\Scripts\activate.bat"
echo [2/5] Updating pip...
python -m pip install --upgrade pip setuptools wheel
if errorlevel 1 goto failed

if not exist "seed-vc\inference.py" (
  echo [3/5] Downloading the open-source Seed-VC engine...
  git --version >nul 2>nul
  if errorlevel 1 (
    echo ERROR: Git for Windows is required for the one-time engine download.
    echo Install Git, then run this file again.
    pause
    exit /b 1
  )
  git clone --depth 1 https://github.com/Plachtaa/seed-vc.git seed-vc
  if errorlevel 1 goto failed
)

echo [4/5] Preparing CPU-compatible dependencies...
python prepare_cpu.py
if errorlevel 1 goto failed

if not exist ".saui-deps-installed" (
  echo Installing CPU-only PyTorch and Seed-VC dependencies. This can take a while.
  python -m pip install torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 --index-url https://download.pytorch.org/whl/cpu
  if errorlevel 1 goto failed
  python -m pip install -r seed-vc\requirements-saui-cpu.txt
  if errorlevel 1 goto failed
  python -m pip install -r requirements.txt
  if errorlevel 1 goto failed
  echo installed>".saui-deps-installed"
)

echo [5/5] Starting SAUI local API...
set SEED_VC_DIR=%CD%\seed-vc
set PYTHON_EXECUTABLE=python
set SAUI_FP16=False
set SAUI_DIFFUSION_STEPS=8
set SAUI_CONVERSION_TIMEOUT=7200
echo.
echo SAUI local API: http://127.0.0.1:8000
echo Health check:   http://127.0.0.1:8000/health
echo Open the Flutter app on this same computer and keep this window open.
echo CPU conversion can be very slow. Start with a short audio clip.
echo.
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
goto end

:failed
echo.
echo SETUP FAILED. Read the first ERROR message above.
pause
exit /b 1

:end
pause
