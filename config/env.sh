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

# Resource ceiling for the container. Doesn't make anything faster — just
# caps the damage if some GApps/Play-services background process runs away,
# which otherwise happens silently and heats/slows the whole host. Kaby
# Lake-R UHD 620 class machine: leave a couple cores/GB free for the host
# itself. Tune to your actual core/RAM count.
: "${DOCKER_CPUS:=3}"
: "${DOCKER_MEM:=4g}"

# Where the redroid-script clone lives (used only by scripts/build-image.sh)
: "${REDROID_SCRIPT_DIR:=$HOME/.cache/droid/redroid-script}"
: "${REDROID_SCRIPT_REPO:=https://github.com/ayasa520/redroid-script.git}"
