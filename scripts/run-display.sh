#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require adb; require scrcpy

adb_wait_boot "$ADB_PORT"
ADB="adb -s ${ADB_HOST}:${ADB_PORT}"

# Let apps be resized/moved inside the one mirrored window instead of
# always filling the whole screen.
$ADB shell settings put global force_resizable_activities 1
$ADB shell settings put global enable_freeform_support 1
$ADB shell settings put global development_settings_enabled 1

# Lock to landscape at the OS level (not just a rotated mirror) so apps
# actually get laid out landscape instead of being letterboxed.
$ADB shell settings put system accelerometer_rotation 0
$ADB shell settings put system user_rotation 1

log "launching scrcpy"
exec scrcpy \
    -s "${ADB_HOST}:${ADB_PORT}" \
    --window-title="droid" \
    --fullscreen \
    --capture-orientation=90 \
    --max-size=1280 \
    --max-fps=30 \
    --video-bit-rate=6M \
    --stay-awake \
    --disable-screensaver \
    --audio-codec=aac \
    --audio-bit-rate=64K
