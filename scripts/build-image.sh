#!/usr/bin/env bash
# Builds a local redroid image with MindTheGapps baked in, using the
# community redroid-script (baking GApps into raw redroid requires system
# partition surgery we don't want to reinvent). Records the resulting
# image tag for the rest of the project to use.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require docker
require git
require python3

mkdir -p "$(dirname "$REDROID_SCRIPT_DIR")"
if [ ! -d "$REDROID_SCRIPT_DIR" ]; then
    log "cloning redroid-script into $REDROID_SCRIPT_DIR"
    git clone --depth 1 "$REDROID_SCRIPT_REPO" "$REDROID_SCRIPT_DIR"
else
    log "updating existing redroid-script checkout"
    git -C "$REDROID_SCRIPT_DIR" pull --ff-only
fi

cd "$REDROID_SCRIPT_DIR"
if [ ! -d venv ]; then
    python3 -m venv venv
    venv/bin/pip install -q -r requirements.txt
fi

log "building redroid:${ANDROID_VERSION} with MindTheGapps (this pulls/builds a large image, be patient)"

# redroid-script downloads into ~/.cache/redroid regardless of our own
# cache dir setting. If a previous run left that root-owned (e.g. from a
# sudo'd docker/make invocation), everything downstream fails deep in a
# traceback — catch it here with an actionable message instead.
RS_CACHE="$HOME/.cache/redroid"
mkdir -p "$RS_CACHE/downloads" 2>/dev/null
if [ ! -w "$RS_CACHE/downloads" ]; then
    die "$RS_CACHE isn't writable by $(whoami) — probably root-owned from an earlier sudo'd run.
Fix with: sudo chown -R \$USER:\$USER $RS_CACHE   (or: sudo rm -rf $RS_CACHE and retry)"
fi

# The flag for this has moved around between commits/forks of this script
# (-mtg, --mindthegapps, etc.) — instead of hardcoding one and breaking every
# time upstream renames it, pull it straight out of --help.
HELP_TEXT=$(venv/bin/python3 redroid.py --help 2>&1 || true)
GAPPS_FLAG=$(echo "$HELP_TEXT" | grep -i 'mindthegapps' | head -1 | grep -oE '\-[A-Za-z][A-Za-z-]*' | head -1)

[ -n "$GAPPS_FLAG" ] || die "couldn't find a MindTheGapps flag in 'redroid.py --help' — run it yourself in $REDROID_SCRIPT_DIR to see what's available:
$HELP_TEXT"

log "using flag: $GAPPS_FLAG"
venv/bin/python3 redroid.py -a "$ANDROID_VERSION" "$GAPPS_FLAG"

# redroid-script's tagging scheme has shifted between forks/versions, so
# find whatever it actually produced rather than assuming a fixed name.
BUILT_TAG=$(docker images --format '{{.Repository}}:{{.Tag}}' \
    | grep -i "redroid.*${ANDROID_VERSION}" | grep -i mindthegapps | head -1)

[ -n "$BUILT_TAG" ] || die "couldn't find the built image in 'docker images' — check the redroid-script output above"

echo "$BUILT_TAG" > "$DROID_ROOT/config/.image-tag"
log "built $BUILT_TAG"
