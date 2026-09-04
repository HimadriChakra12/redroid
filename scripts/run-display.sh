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

# Window animations add render work behind every frame that then has to get
# software-encoded (see note below) — cutting them reduces both draw and
# encode load, not just visual snappiness.
$ADB shell settings put global window_animation_scale 0
$ADB shell settings put global transition_animation_scale 0
$ADB shell settings put global animator_duration_scale 0

# redroid has no real hardware video-encode passthrough, so whatever
# resolution/fps/bitrate scrcpy asks for gets encoded by Android's *software*
# H.264 encoder running inside the container — i.e. on your CPU. Set here to
# match the T480s panel natively (1920x1080 @ 60Hz) since quality is the
# priority now — drop these back down (see git history / previous values:
# 960/24/3M) if the heat becomes a problem again.
log "launching scrcpy"
exec scrcpy \
    -s "${ADB_HOST}:${ADB_PORT}" \
    --window-title="droid" \
    --fullscreen \
    --no-audio \
    --max-size=1920 \
    --max-fps=60 \
    --video-bit-rate=8M \
    --stay-awake \
    --disable-screensaver
