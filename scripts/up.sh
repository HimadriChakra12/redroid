#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require docker

TAG=$(resolve_image_tag)
mkdir -p "$DROID_DIR"

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    log "container $CONTAINER_NAME already exists, starting it"
    docker start "$CONTAINER_NAME" >/dev/null
else
    log "creating container $CONTAINER_NAME from $TAG, data in $DROID_DIR"
    docker run -itd \
        --name "$CONTAINER_NAME" \
        --privileged \
        --restart=unless-stopped \
        -v "$DROID_DIR:/data" \
        -p "${ADB_PORT}:5555" \
        --device /dev/dri:/dev/dri \
        "$TAG" \
        androidboot.redroid_gpu_mode=host \
        androidboot.use_memfd=1 \
        >/dev/null
fi

adb_wait_boot "$ADB_PORT"

FRESH_MARKER="$DROID_DIR/.provisioned"
if [ ! -f "$FRESH_MARKER" ]; then
    log "fresh .droid dir detected — run 'make setup' to install apps and strip the defaults"
fi
