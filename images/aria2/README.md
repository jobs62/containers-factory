# aria2 image

Stock `aria2c` from the alpine community repo — no init system, no entrypoint
scripts; config comes 100% from the mounted config file. Successor of the lost
`git.analphabet.me/droper/aria2` image; the interim deployment used
`nixery.dev/aria2` (digest-pinned) — see the seedbox migration note below.

- alpine `3.24.2` (Renovate-managed via `ARG ALPINE_TAG`), aria2 `1.37.0` —
  same upstream version the current nixery pin serves, so switching images is
  a no-op version-wise.
- runs as `1000:2000` (matches the seedbox securityContext and the torrents
  PVC fsGroup); works with a read-only rootfs.
- `ENTRYPOINT ["/usr/bin/aria2c"]`, `CMD ["--conf-path=/config/aria2.conf"]`
  (the alpine package installs the binary at `/usr/bin/aria2c`, unlike
  nixery's `/bin/aria2c`).

## Smoke test

`smoke-test.sh` builds the image, boots it with a throwaway config (RPC on,
BT listeners off) and checks `aria2.getVersion` over the JSON-RPC endpoint —
the same check that validated the nixery image end-to-end. CI runs it on
every build of this image.

## Migrating the seedbox deployment back (when ready)

`application/seedbox/base/download/deployment.yaml`:

1. image → `ghcr.io/jobs62/aria2:<VERSION>` (or digest pin after pull)
2. command: `/bin/aria2c` → `/usr/bin/aria2c`

No other change: user/gid, ports, mounts and the configMap stay identical.
