#!/usr/bin/env bash
# Sourced by every script. Not meant to be run directly.
set -euo pipefail

DROID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$DROID_ROOT/config/env.sh"

IMAGE_TAG_FILE="$DROID_ROOT/config/.image-tag"

log()  { printf '\033[1;34m[droid]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[droid]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[droid]\033[0m %s\n' "$*" >&2; exit 1; }

require() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }

# The exact tag redroid-script produces varies by version/fork, so
# build-image.sh records whatever it actually built into IMAGE_TAG_FILE.
# Everything else reads it from there instead of guessing.
resolve_image_tag() {
    if [ -f "$IMAGE_TAG_FILE" ]; then
        cat "$IMAGE_TAG_FILE"
    else
        echo "$BASE_TAG"
    fi
}

adb_wait_boot() {
    local port="$1" tries=180
    require adb

    local adb_check
    if ! adb_check=$(adb version 2>&1); then
        die "adb doesn't actually run on this system, even though it's on PATH:
$adb_check
Fix your adb install before retrying (e.g. on Arch this is often android-tools
desynced from a protobuf update — 'sudo pacman -Syu' or reinstall android-tools)."
    fi

    log "waiting for container to finish booting on :$port (first boot with GApps can take several minutes)"
    adb connect "${ADB_HOST}:${port}" >/dev/null 2>&1 || true
    until adb -s "${ADB_HOST}:${port}" shell getprop sys.boot_completed 2>/dev/null | grep -q 1; do
        tries=$((tries - 1))
        [ "$tries" -le 0 ] && die "container never finished booting after 6 minutes — check 'docker logs droid'"
        sleep 2
        adb connect "${ADB_HOST}:${port}" >/dev/null 2>&1 || true
    done
    log "boot complete"
}

# Fetch the latest APK for an F-Droid package id into $2.
dl_fdroid_apk() {
    local pkg="$1" out="$2"
    require curl; require jq
    log "resolving latest $pkg from F-Droid"
    local apk_name
    apk_name=$(curl -fsSL "https://f-droid.org/api/v1/packages/${pkg}" \
        | jq -r '.packages | sort_by(.versionCode) | last | .apkName')
    [ -n "$apk_name" ] && [ "$apk_name" != "null" ] || die "could not resolve $pkg on F-Droid"
    curl -fsSL "https://f-droid.org/repo/${apk_name}" -o "$out"
    log "downloaded $apk_name -> $out"
}

# Fetch the newest release APK asset from a GitHub repo into $2.
dl_github_release_apk() {
    local repo="$1" out="$2"
    require curl; require jq
    log "resolving latest release APK from github:$repo"
    local url
    url=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
        | jq -r '.assets[] | select(.name | test("\\.apk$")) | .browser_download_url' | head -1)
    [ -n "$url" ] || die "no APK asset found in latest release of $repo"
    curl -fsSL "$url" -o "$out"
    log "downloaded $(basename "$url") -> $out"
}

# Fetch a direct APK URL as-is into $2.
dl_direct_apk() {
    local url="$1" out="$2"
    require curl
    log "downloading $url"
    curl -fsSL "$url" -o "$out"
}
