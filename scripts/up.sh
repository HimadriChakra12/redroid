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

# Symlink to Android's shared storage (Download, Pictures, DCIM, ...), for
# browsing/copying out files the device itself wrote. This directory is
# owned by root/media_rw inside the container (privileged, non-userns-
# remapped), so it isn't host-readable by default — grant read+traverse via
# a POSIX ACL (adds a permission without touching the existing root
# ownership Android needs to keep writing there; -d makes it apply to files
# created later too). Tried non-interactively (sudo -n) so this never hangs
# waiting on a password prompt inside a script.
STORAGE_LINK="$HOME/.droidstorage"
MEDIA_DIR="$DROID_DIR/media/0"
ln -sfn "$MEDIA_DIR" "$STORAGE_LINK" 2>/dev/null || true

if command -v setfacl >/dev/null 2>&1; then
    if sudo -n setfacl -R -m "u:$(id -un):rX" -d -m "u:$(id -un):rX" "$DROID_DIR/media" 2>/dev/null; then
        log "storage readable at $STORAGE_LINK"
    else
        warn "$STORAGE_LINK isn't readable yet — run this once, then it'll stay that way:"
        warn "  sudo setfacl -R -m u:$(id -un):rX -d -m u:$(id -un):rX $DROID_DIR/media"
    fi
else
    warn "'setfacl' not found (pacman -S acl) — can't grant read access to $STORAGE_LINK automatically."
fi

FRESH_MARKER="$DROID_DIR/.provisioned"
if [ ! -f "$FRESH_MARKER" ]; then
    log "fresh .droid dir detected — run 'make setup' to install apps and strip the defaults"
fi
