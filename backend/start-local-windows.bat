@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ==========================================
echo SAUI - Local Windows CPU Engine
echo ==========================================
echo This uses CPU mode. It does not require NVIDIA CUDA.
echo First setup downloads Python packages and public model files.
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
    echo ERROR: Git is required for the one-time engine download.
    echo Install Git for Windows, then run this file again.
    pause
    exit /b 1
  )
  git clone --depth 1 https://github.com/Plachtaa/seed-vc.git seed-vc
  if errorlevel 1 goto failed
)

if not exist ".saui-deps-installed" (
  echo [4/5] Installing CPU-only PyTorch and Seed-VC dependencies.
  echo This may take a while and needs several GB of free disk space.
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Get-Content 'seed-vc\requirements.txt' | Where-Object { $_ -notmatch '^(torch|torchvision|torchaudio)(\s|=|<|>|$)' } | Set-Content 'seed-vc\requirements-saui-cpu.txt'"
  if errorlevel 1 goto failed

  python -m pip install torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 --index-url https://download.pytorch.org/whl/cpu
  if errorlevel 1 goto failed
  python -m pip install -r seed-vc\requirements-saui-cpu.txt
  if errorlevel 1 goto failed
  powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content seed-vc\inference.py -Raw).Replace('torch_dtype=torch.float16','torch_dtype=torch.float32').Replace('hubert_model = hubert_model.half()','hubert_model = hubert_model.float()').Replace('wav2vec_model = wav2vec_model.half()','wav2vec_model = wav2vec_model.float()').Replace('ori_inputs.input_values.half()','ori_inputs.input_values.float()') | Set-Content seed-vc\inference.py"
  python -m pip install -r requirements.txt
  if errorlevel 1 goto failed
  echo installed>".saui-deps-installed"
)

echo [5/5] Starting SAUI local API...
set SEED_VC_DIR=%CD%\seed-vc
set PYTHON_EXECUTABLE=python
set SAUI_FP16=False
set SAUI_DIFFUSION_STEPS=8
set SAUI_CONVERSION_TIMEOUT=3600
echo.
echo SAUI local API: http://127.0.0.1:8000
echo Health check:   http://127.0.0.1:8000/health
echo Keep this window open while converting.
echo CPU mode may be very slow; start with a short audio sample.
echo.
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
goto end

:failed
echo.
echo SETUP FAILED. The error above identifies the failed install step.
pause
exit /b 1

:end
pause
