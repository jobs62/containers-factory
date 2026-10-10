# immich-ml-seeded

Derived image of `ghcr.io/immich-app/immich-machine-learning` with the ML
models baked into `/cache`, so the immich-machine-learning service can run
**without a PVC** for its model cache. Based on immich v3.3.1 (layout of
`machine-learning/immich_ml` as of tag v3.3.1).

Verified layout sources: `immich_ml/models/base.py` (`_cache_dir_default`,
`download`, `model_path`) and the HF repos `immich-app/<model>` branch `v2`,
whose `textual/`, `visual/`, `detection/`, `recognition/` subfolders map 1:1
onto the runtime model-type directories.

## Build

```sh
docker build -t immich-ml-seeded:v3.3.1 .
```

Build args:

- `SEED_MODELS` — space-separated model names. Default = v3.3.1 server
  defaults: `ViT-B-32__openai buffalo_l PP-OCRv5_mobile`. If you changed the
  models in Immich's admin UI (Machine Learning settings), list those instead.
- `BASE_IMAGE` — pinned by digest to the multi-arch manifest list of
  `v3.3.1`. For an accelerated variant use the matching tag, e.g.
  `ghcr.io/immich-app/immich-machine-learning:v3.3.1-cuda` (formats differ
  per device; one image per device variant).

The seed script downloads from HF with `ignore_patterns=["*.armnn","*.rknn"]`
(ONNX format). For the `-armnn` base image, set
`--build-arg SEED_IGNORE_PATTERNS="*.rknn"` to also bake the `.armnn` files.

The image sets `MACHINE_LEARNING_MODEL_REVISION=v2` (the official
docker-compose default). Do not override this env at runtime, or the layout
won't match.

## Kubernetes: stateless ML without PVC

The baked `/cache` covers the model files (never written at runtime when
present). What still writes at runtime: ORT session artifacts under each
model's `<type>/onnx/` dir (regenerated every pod start; keyed by CPU
micro-arch / GPU driver / ORT version in `manifest.json`), GPU JIT caches
(`/cache/jit`), HF hub metadata (`/cache/hf-cache`), and `/tmp`.

Give those paths scratch volumes and mount everything else read-only. Use a
**separate volume per path** (a single emptyDir mounted at several paths
without `subPath` would merge the artifact trees — the manifests do not
encode the model name, which can make the wrong prepared graph load).

Strategic-merge patch (adjust image + paths to your model set):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: immich-machine-learning
spec:
  template:
    spec:
      containers:
        - name: immich-machine-learning
          image: <registry>/immich-ml-seeded:v3.3.1
          volumeMounts:
            - { name: scratch-tmp, mountPath: /tmp }
            - { name: scratch-clip-textual, mountPath: /cache/clip/ViT-B-32__openai/v2/textual/onnx }
            - { name: scratch-clip-visual, mountPath: /cache/clip/ViT-B-32__openai/v2/visual/onnx }
            - { name: scratch-face-det, mountPath: /cache/facial-recognition/buffalo_l/v2/detection/onnx }
            - { name: scratch-face-rec, mountPath: /cache/facial-recognition/buffalo_l/v2/recognition/onnx }
            - { name: scratch-ocr-det, mountPath: /cache/ocr/PP-OCRv5_mobile/v2/detection/onnx }
            - { name: scratch-ocr-rec, mountPath: /cache/ocr/PP-OCRv5_mobile/v2/recognition/onnx }
            - { name: scratch-hf, mountPath: /cache/hf-cache }
            - { name: scratch-jit, mountPath: /cache/jit }
      volumes:
        - { name: scratch-tmp, emptyDir: {} }
        - { name: scratch-clip-textual, emptyDir: {} }
        - { name: scratch-clip-visual, emptyDir: {} }
        - { name: scratch-face-det, emptyDir: {} }
        - { name: scratch-face-rec, emptyDir: {} }
        - { name: scratch-ocr-det, emptyDir: {} }
        - { name: scratch-ocr-rec, emptyDir: {} }
        - { name: scratch-hf, emptyDir: {} }
        - { name: scratch-jit, emptyDir: {} }
```

Cost of the compromise: models load straight from the image; only the ORT
"prepared" graphs are regenerated per pod start (a few seconds on CPU; can
be minutes on GPU-backed providers like TensorRT/OpenVINO).

### Zero-scratch variant (everything baked, fully read-only)

You can also bake the prepared-session artifacts into the image: warm the
service once on a node identical to the target (same CPU micro-architecture,
same GPU + driver, same base image tag), copy `/cache` into the image, and
mount nothing. `fresh()` in `sessions/ort.py` then always hits. Only worth it
for homogeneous clusters; on heterogeneous nodes the manifest "facts" (CPU
flags, GPU UUID/driver) won't match and a read-only mount would crash the
load. The scratch volumes above are the robust default.

## Behavior notes

- With models present and uncorrupted, `download()` and `clear_cache()` never
  fire — the service only reads. A missing model logs a clear error on first
  request; add it to `SEED_MODELS` and rebuild.
- Keep `MACHINE_LEARNING_CACHE_FOLDER=/cache` (image default). The seeded
  layout is `<cache_folder>/<task>/<model>/<revision>/<type>/model.onnx`.
- Regenerate the image when you upgrade Immich: the server pins the ML config
  and revision; the baked layout is version-specific.
- Image size grows by ~1–2 GB depending on the model set (CLIP visual+textual
  ~600 MB, buffalo_l ~300 MB, PP-OCRv5_mobile ~20 MB, roughly).