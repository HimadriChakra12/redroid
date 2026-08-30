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
        androidboot.redroid_width=1920 \
        androidboot.redroid_height=1080 \
        androidboot.redroid_dpi=280 \
        >/dev/null
fi

adb_wait_boot "$ADB_PORT"

# Best-effort symlink to Android's shared storage, for browsing files the
# device itself wrote (screenshots, exports, etc). This directory is owned
# by root/media_rw inside the container, so it may not be host-readable
# without a one-time `sudo setfacl -R -m u:$(id -un):rX -d -m u:$(id -un):rX
# $DROID_DIR/media` — that's optional and only matters for reading device
# output. For getting files FROM the host TO the device, use `make push
# FILES="..."` instead (scripts/push.sh) — it goes over adb and needs no
# host permissions at all.
STORAGE_LINK="$HOME/.droidstorage"
MEDIA_DIR="$DROID_DIR/media/0"
ln -sfn "$MEDIA_DIR" "$STORAGE_LINK" 2>/dev/null || true

FRESH_MARKER="$DROID_DIR/.provisioned"
if [ ! -f "$FRESH_MARKER" ]; then
    log "fresh .droid dir detected — run 'make setup' to install apps and strip the defaults"
fi
