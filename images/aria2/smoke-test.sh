#!/usr/bin/env bash
# End-to-end smoke test for the aria2 image.
# Boots it with a throwaway config + empty download dir and checks the
# JSON-RPC answers. Mirrors the k8s deployment's mounts.
#
# Local:  ./smoke-test.sh                      (builds ./Dockerfile as aria2:smoke)
# CI:     IMAGE=<registry/image:tag> SKIP_BUILD=1 ./smoke-test.sh
set -euo pipefail

IMAGE="${IMAGE:-aria2:smoke}"
NAME=aria2-smoke
PORT="${PORT:-16800}"

cd "$(dirname "$0")"

if [ -z "${SKIP_BUILD:-}" ]; then
  docker build -t "$IMAGE" .
fi

echo "== binary + identity ($IMAGE)"
docker run --rm "$IMAGE" --version | head -1
docker run --rm --entrypoint /bin/sh "$IMAGE" -c 'id' | grep -q 'uid=1000' \
  && echo "runs as uid 1000: OK"

echo "== RPC boot test"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"; docker rm -f "$NAME" >/dev/null 2>&1 || true' EXIT

cat > "$TMP/aria2.conf" <<EOF
dir=/media/torrents/
enable-rpc=true
rpc-listen-all=true
rpc-listen-port=6800
enable-dht=false
listen-port=16881
seed-time=0
EOF

docker run -d --name "$NAME" \
  -p "$PORT:6800" \
  -v "$TMP:/config:ro" \
  -v "$TMP/dl:/media/torrents" \
  "$IMAGE" >/dev/null

RESP=""
for i in $(seq 1 20); do
  RESP=$(curl -fsS "http://localhost:$PORT/jsonrpc" \
    -d '{"jsonrpc":"2.0","id":"t","method":"aria2.getVersion"}' 2>/dev/null || true)
  [ -n "$RESP" ] && break
  sleep 0.5
done
echo "$RESP"
echo "$RESP" | grep -q '"version"' && echo "RPC getVersion: OK" || { echo "RPC check FAILED"; exit 1; }
