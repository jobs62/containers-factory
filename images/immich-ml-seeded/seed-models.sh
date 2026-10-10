#!/bin/sh
# Seed /cache with Immich ML models, in the exact layout immich_ml expects.
#
# Layout (immich_ml/models/base.py @ v3.3.1):
#   <cache_folder>/<task.value>/<clean_name(model)>/[<revision>/]<type.value>/...
#   - revision level present only when MACHINE_LEARNING_MODEL_REVISION != "main"
#   - type.value: clip -> textual|visual, facial-recognition & ocr -> detection|recognition
#   - clean_name: basename, ':'/'/'->'_', '.'->''  (e.g. ViT-B-32__openai)
#
# Download: snapshot_download(repo="immich-app/<name>", revision=<branch>, ...)
# with local_dir == the model's cache_dir. The HF repos store files under
# <type>/ subfolders (textual/, visual/, detection/, recognition/) plus a repo
# root config.json, which map 1:1 onto the runtime layout — so the repo tree IS
# the runtime tree. One snapshot_download per repo downloads everything; the
# loop re-checks each model type exists afterwards.
#
# Env consumed (set in Dockerfile):
#   MACHINE_LEARNING_MODEL_REVISION   branch to download (v2)
#   MACHINE_LEARNING_MODEL_ORGANIZATION  HF org (immich-app)
set -eu

MODELS="${1:-ViT-B-32__openai buffalo_l PP-OCRv5_mobile}"
# ONNX format for cpu/cuda/openvino/rocm images. For the -armnn image variant,
# set SEED_IGNORE_PATTERNS="*.rknn" so *.armnn files are also baked.
IGNORE="${SEED_IGNORE_PATTERNS:-*.armnn *.rknn}"

python3 - "$MODELS" "$IGNORE" <<'PYEOF'
import sys

from huggingface_hub import snapshot_download

from immich_ml.config import settings
from immich_ml.models.clip.textual import MClipTextualEncoder, OpenClipTextualEncoder
from immich_ml.models.clip.visual import OpenClipVisualEncoder
from immich_ml.models.constants import get_model_source
from immich_ml.models.facial_recognition.detection import FaceDetector
from immich_ml.models.facial_recognition.recognition import FaceRecognizer
from immich_ml.models.ocr.detection import TextDetector
from immich_ml.models.ocr.recognition import TextRecognizer
from immich_ml.schemas import ModelFormat

names = [n.strip() for n in sys.argv[1].split() if n.strip()]
ignore = [p for p in sys.argv[2].split() if p.strip()]

classes_by_source = {
    "openclip": [OpenClipTextualEncoder, OpenClipVisualEncoder],
    "mclip": [MClipTextualEncoder, OpenClipVisualEncoder],
    "insightface": [FaceDetector, FaceRecognizer],
    "paddle": [TextDetector, TextRecognizer],
}

for name in names:
    source = get_model_source(name)
    if source is None:
        raise SystemExit(f"unknown model: {name!r} (not in immich_ml model lists)")
    for cls in classes_by_source[source.value]:
        model = cls(name, model_format=ModelFormat.ONNX)
        print(f"[seed] {source.value} {name} -> {model.cache_dir} ({model.model_type.value})")
        snapshot_download(
            f"{settings.model_organization}/{name}",
            revision=settings.model_revision,
            cache_dir=model.cache_dir,
            local_dir=model.cache_dir,
            ignore_patterns=ignore,
        )
        if not model.cached:
            raise SystemExit(f"seed check failed: {model.model_path} missing after download")
        print(f"[seed] OK {model.model_path}")

print("[seed] done")
PYEOF

# Strip HF hub metadata blobs (*.msgpack) so the image keeps only model files.
# (With ignore_patterns covering them at download they are absent; this is a
# belt-and-suspenders cleanup for hub versions that still fetch metadata.)
python3 - <<'PYEOF'
from pathlib import Path

from immich_ml.config import settings

root = Path(settings.cache_folder)
removed = 0
for p in root.rglob("*.msgpack"):
    p.unlink(missing_ok=True)
    removed += 1
print(f"[seed] cleaned {removed} hub metadata blobs under {root}")
PYEOF
