# Immich ML with models baked in (read-only-friendly image)
#
# Builds on the official image and pre-seeds /cache with the models your
# Immich server uses, so the ML service never needs to download or write to
# its model storage at runtime.
#
# Build:  docker build -t immich-ml-seeded:v3.3.1 .
# See README.md for usage and the Kubernetes snippet.

# Pin the base by digest (multi-arch manifest-list digest of the official tag;
# resolves per build platform). To update:
# docker buildx imagetools inspect ghcr.io/immich-app/immich-machine-learning:v3.3.1
# ARG BASE_IMAGE=ghcr.io/immich-app/immich-machine-learning:v3.3.1
ARG BASE_IMAGE=ghcr.io/immich-app/immich-machine-learning@sha256:513c831cfb010ad319341a0c86b42c575a0d5b688d3e8cae346ee624074a58ed

FROM ${BASE_IMAGE}

# Must match the layout seeded below and the revision your deployment expects.
# The official docker-compose sets MACHINE_LEARNING_MODEL_REVISION=v2; baking it
# here keeps the image self-consistent (the seed script reads this same value).
# Override with --build-arg MODEL_REVISION=<branch> only if you also adapt the
# sanity-check paths below.
ARG MODEL_REVISION=v2
ENV MACHINE_LEARNING_MODEL_REVISION=${MODEL_REVISION}

# Default model set = v3.3.1 server defaults (CLIP / facial recognition / OCR).
# Override at build time: --build-arg SEED_MODELS="ViT-B-32__openai buffalo_l PP-OCRv5_mobile"
ARG SEED_MODELS="ViT-B-32__openai buffalo_l PP-OCRv5_mobile"

# Seed step: runs once at build time, needs network. The seed script downloads
# the models into /cache with the exact layout the ML service expects.
COPY --chmod=755 seed-models.sh /tmp/seed-models.sh
RUN /tmp/seed-models.sh "$SEED_MODELS" && rm /tmp/seed-models.sh

# Sanity check: the expected model files must exist in the final layout.
# <cache_folder>/<task>/<name>/<revision>/<type>/model.onnx
# NOTE: adapt these lines if you override SEED_MODELS.
RUN set -eu; \
    test -f /cache/clip/ViT-B-32__openai/v2/textual/model.onnx; \
    test -f /cache/clip/ViT-B-32__openai/v2/visual/model.onnx; \
    test -f /cache/facial-recognition/buffalo_l/v2/detection/model.onnx; \
    test -f /cache/facial-recognition/buffalo_l/v2/recognition/model.onnx; \
    test -f /cache/ocr/PP-OCRv5_mobile/v2/detection/model.onnx; \
    test -f /cache/ocr/PP-OCRv5_mobile/v2/recognition/model.onnx; \
    echo "seed OK: all model files present"

# Entrypoint/cmd are inherited unchanged from the base image.
# Runtime writes go to /tmp and to the session-artifact directories, which should
# be backed by writable scratch in read-only deployments (see README.md).