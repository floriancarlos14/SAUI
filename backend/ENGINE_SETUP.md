# SAUI GPU conversion engine

This container runs the SAUI FastAPI adapter and the Seed-VC singing voice conversion model.

## Runtime requirement

This is a model server, not a website. It needs a Linux host with an NVIDIA GPU, a compatible NVIDIA driver, Docker, and NVIDIA Container Toolkit. The existing AppDeploy backend serves the website and forwards conversion requests; it is not a GPU model runtime.

## Start the engine

On the GPU host, from this directory:

```sh
docker compose up --build -d
curl http://localhost:8000/health
```

The health response must show `inference_ready: true`. The first conversion downloads the public model weights and caches them in the Docker volume.

## Connect the SAUI website

Set the existing AppDeploy backend secret `SAUI_ENGINE_URL` to the reachable base URL of this server, without a trailing slash. The SAUI website forwards uploads to its `POST /convert` endpoint.

## Model

Seed-VC supports zero-shot singing voice conversion. Its V1 singing model uses the 44.1 kHz configuration. Review the upstream GPL-3.0 license before redistributing modified builds:
https://github.com/Plachtaa/seed-vc

Only use songs and voice samples you own or have permission to process.
