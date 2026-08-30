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

# The display buffer itself is booted landscape-shaped (see up.sh's
# androidboot.redroid_width/height), so no rotation trick is needed here —
# user_rotation should stay at its natural default (0) since the "natural"
# orientation of a landscape-shaped buffer already IS landscape.

log "launching scrcpy"
exec scrcpy \
    -s "${ADB_HOST}:${ADB_PORT}" \
    --window-title="droid" \
    --fullscreen \
    --max-fps=30 \
    --video-bit-rate=6M \
    --stay-awake \
    --disable-screensaver \
    --audio-codec=aac \
    --audio-bit-rate=64K
