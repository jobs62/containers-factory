# Stock aria2 from the alpine community repo — no init system, no entrypoint
# scripts; config comes 100% from the mounted config file. Replaces the lost
# git.analphabet.me/droper/aria2 image (see images/aria2/README.md).
# UID 1000 / GID 2000 match the seedbox deployment securityContext and the
# fsGroup on the torrents PVC.
ARG ALPINE_TAG=3.24.2@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

FROM alpine:${ALPINE_TAG}

RUN apk add --no-cache aria2 \
    && addgroup -g 2000 aria2 \
    && adduser -D -H -u 1000 -G aria2 -h /nonexistent -s /sbin/nologin aria2

USER 1000:2000

EXPOSE 6800 6881 6881/udp

ENTRYPOINT ["/usr/bin/aria2c"]
CMD ["--conf-path=/config/aria2.conf"]

LABEL org.opencontainers.image.title="aria2" \
      org.opencontainers.image.description="aria2 from alpine community, stock binary, no init system" \
      org.opencontainers.image.source="https://github.com/jobs62/containers-factory"