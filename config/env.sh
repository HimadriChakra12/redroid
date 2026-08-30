#!/usr/bin/env bash
# Shared config for the droid project. Edit this file, not the scripts.

# Where Android's /data lives on the host. Kept outside the repo on purpose.
: "${DROID_DIR:=$HOME/.droid}"

# Docker container/image naming
: "${CONTAINER_NAME:=droid}"
: "${ANDROID_VERSION:=13.0.0}"          # passed to redroid-script's -a flag
: "${BASE_TAG:=redroid/redroid:${ANDROID_VERSION}_64only-mindthegapps}"
: "${IMAGE_TAG:=droid/redroid-personal:${ANDROID_VERSION}}"

# adb/scrcpy
: "${ADB_PORT:=5555}"
: "${ADB_HOST:=127.0.0.1}"

# Where the redroid-script clone lives (used only by scripts/build-image.sh)
: "${REDROID_SCRIPT_DIR:=$HOME/.cache/droid/redroid-script}"
: "${REDROID_SCRIPT_REPO:=https://github.com/ayasa520/redroid-script.git}"
