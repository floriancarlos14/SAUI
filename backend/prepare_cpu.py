from pathlib import Path

root = Path(__file__).resolve().parent
seed = root / "seed-vc"
requirements = seed / "requirements.txt"
inference = seed / "inference.py"

if not requirements.is_file() or not inference.is_file():
    raise SystemExit("Seed-VC download is incomplete. Delete backend/seed-vc and run the launcher again.")

# Keep upstream dependencies but preserve the CPU-only PyTorch installed separately.
lines = requirements.read_text(encoding="utf-8").splitlines()
blocked = ("torch", "torchvision", "torchaudio")
kept = []
for line in lines:
    item = line.strip().lower()
    package = item.split("=", 1)[0].split("<", 1)[0].split(">", 1)[0].split("[", 1)[0].split(" ", 1)[0]
    if package not in blocked and not item.startswith("--index-url"):
        kept.append(line)
(seed / "requirements-saui-cpu.txt").write_text("\n".join(kept) + "\n", encoding="utf-8")

# Half-precision transformer weights are unsupported by many CPU operators.
source = inference.read_text(encoding="utf-8")
for old, new in {
    "torch_dtype=torch.float16": "torch_dtype=torch.float32",
    "hubert_model = hubert_model.half()": "hubert_model = hubert_model.float()",
    "wav2vec_model = wav2vec_model.half()": "wav2vec_model = wav2vec_model.float()",
    "ori_inputs.input_values.half()": "ori_inputs.input_values.float()",
}.items():
    source = source.replace(old, new)
inference.write_text(source, encoding="utf-8", newline="\n")
print("CPU compatibility files prepared (UTF-8, FP32 transformer paths).")
