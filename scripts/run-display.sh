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

log "launching scrcpy"
exec scrcpy \
    -s "${ADB_HOST}:${ADB_PORT}" \
    --window-title="droid" \
    --max-size=1600 \
    --stay-awake \
    --disable-screensaver
