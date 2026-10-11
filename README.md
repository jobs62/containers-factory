# containers-factory

Image factory for the homelab: one repo, one workflow, builds each
`images/<name>/` and pushes to `ghcr.io/jobs62/<name>`.

## Layout

```
images/
  <image-name>/
    Dockerfile      # required
    VERSION         # required, becomes the main tag (e.g. v3.3.1)
    ...             # build context (scripts, configs, patches)
.github/
  workflows/build.yml
  renovate.json5    # extends jobs62/infra central config
```

## Workflow behavior

- **push / PR touching `images/**`**: builds only images whose files changed
  (path filter + `git diff` between `before` and the pushed sha). PRs build
  without pushing (validation); merges to `main` push.
- **workflow_dispatch**: optional `image` input to rebuild one image, empty =
  all.
- **Tags**: `<VERSION>` and `<VERSION>-<run number>` — immutable-style tags,
  no floating `latest`.
- **Registry auth**: `GITHUB_TOKEN` with `packages: write` — no PAT involved.
- **Cache**: GHA cache (`type=gha`) per image.
- **Smoke tests**: images shipping a `smoke-test.sh` run it after build
  (the image is exported into the daemon for that; CI tests the exact built
  image via `IMAGE=<tag> SKIP_BUILD=1`).

## Renovate

`.github/renovate.json5` extends the central config
(`github>jobs62/infra//renovate-config/default.json5`) and adds a regex
manager for digest-pinned base images passed through `ARG BASE_IMAGE=...`
(the stock docker manager only reads direct `FROM` lines). Bumps arrive as
PRs; merging one triggers a rebuild with the new base digest.

## Adding an image

```
mkdir images/<name>
# Dockerfile (+ VERSION). Sanity checks inside the Dockerfile act as CI tests.
```

The discovery job picks it up on the next push touching it.

## Images

- `images/immich-ml-seeded` — see `images/immich-ml-seeded/README.md` (Immich ML
  with models baked into `/cache`, PVC-free).
- `images/aria2` — see `images/aria2/README.md` (stock aria2c on alpine,
  successor of the lost gitea image, with RPC smoke test).