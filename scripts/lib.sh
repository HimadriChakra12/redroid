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

    # With GApps present, Play Protect's package verifier intercepts adb
    # installs too and phones home to check unrecognized APKs. Well-known
    # apps (already in Play Protect's cache) install instantly; obscure or
    # self-hosted APKs can silently stall for minutes waiting on that
    # round-trip. This setting scopes the skip to adb-initiated installs
    # only — it doesn't touch Play Store-side scanning.
    adb -s "${ADB_HOST}:${port}" shell settings put global verifier_verify_adb_installs 0 \
        </dev/null >/dev/null 2>&1 || warn "couldn't disable adb-install verification (non-fatal, installs may just be slower)"
}

# Check whether a package is already installed on the device. $1 is the full
# "adb -s host:port" prefix, $2 is the Android package name (e.g.
# com.aurora.store). Returns 0 (true) if installed, 1 otherwise.
is_pkg_installed() {
    local adb_prefix="$1" pkg="$2"
    $adb_prefix shell pm path "$pkg" </dev/null >/dev/null 2>&1
}

# Extract the package name (applicationId) from a downloaded .apk. Used for
# github/url sources where we don't know the package name up front — only
# the apk file tells us. Echoes the package name, or nothing if it can't be
# determined (missing aapt/aapt2, or an unparseable apk).
extract_apk_package() {
    local apk="$1"
    if command -v aapt >/dev/null 2>&1; then
        aapt dump badging "$apk" 2>/dev/null \
            | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -1
    elif command -v aapt2 >/dev/null 2>&1; then
        aapt2 dump badging "$apk" 2>/dev/null \
            | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -1
    fi
}

# Download $1 into $2 with a visible progress bar. curl's own --progress-bar
# already writes to stderr, so this is just a thin, named wrapper used by
# every dl_* function below for consistent behavior.
_curl_with_progress() {
    local url="$1" out="$2"
    curl -f -A "droid-provisioner/1.0 (+https://github.com/HimadriChakra12)" \
        -L --progress-bar -o "$out" "$url"
}

# Fetch the latest APK for an F-Droid package id into $2.
#
# NOTE: the v1 packages API used to return an explicit "apkName" field per
# package, which is what this used to key off of. That field is gone now —
# the API only returns versionName/versionCode. F-Droid's repo layout is
# still a fixed, documented convention though: {packageName}_{versionCode}.apk
# under https://f-droid.org/repo/, so we build the filename ourselves instead
# of relying on a field that no longer exists.
dl_fdroid_apk() {
    local pkg="$1" out="$2"
    require curl; require jq
    log "resolving latest $pkg from F-Droid"
    local http_code body version_code apk_name
    local api_url="https://f-droid.org/api/v1/packages/${pkg}"
    # Don't let -f swallow the body on a non-200: capture status and body
    # separately so a failure is diagnosable instead of a bare "could not
    # resolve".
    body=$(curl -sSL -A "droid-provisioner/1.0 (+https://github.com/HimadriChakra12)" \
        -w $'\n%{http_code}' "$api_url") || die "curl request to $api_url failed outright (network/DNS?)"
    http_code=$(printf '%s' "$body" | tail -n1)
    body=$(printf '%s' "$body" | sed '$d')

    if [ "$http_code" != "200" ]; then
        warn "F-Droid API returned HTTP $http_code for $pkg"
        warn "body: $(printf '%s' "$body" | head -c 300)"
        die "could not resolve $pkg on F-Droid (HTTP $http_code)"
    fi

    version_code=$(printf '%s' "$body" | jq -r '.packages | sort_by(.versionCode) | last | .versionCode')
    if [ -z "$version_code" ] || [ "$version_code" = "null" ]; then
        warn "F-Droid API returned 200 but no usable versionCode for $pkg"
        warn "raw response: $(printf '%s' "$body" | head -c 500)"
        die "could not resolve $pkg on F-Droid (unexpected response shape)"
    fi
    apk_name="${pkg}_${version_code}.apk"

    log "downloading $apk_name"
    _curl_with_progress "https://f-droid.org/repo/${apk_name}" "$out" \
        || die "download of $apk_name failed (bad filename guess? check https://f-droid.org/repo/${apk_name} by hand)"
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
    log "downloading $(basename "$url")"
    _curl_with_progress "$url" "$out" || die "download of $url failed"
    log "downloaded $(basename "$url") -> $out"
}

# Fetch a direct APK URL as-is into $2.
dl_direct_apk() {
    local url="$1" out="$2"
    require curl
    log "downloading $url"
    _curl_with_progress "$url" "$out" || die "download of $url failed"
    log "downloaded $(basename "$url") -> $out"
}

# Install an APK over adb with a lightweight progress spinner, since `adb
# install` gives no percentage of its own — just silence until it prints
# "Success"/"Failure" at the end. $1 is the full "adb -s host:port" prefix
# (as used elsewhere in this project), $2 is the apk path.
adb_install_with_progress() {
    local adb_prefix="$1" apk="$2"
    local size_h
    size_h=$(du -h "$apk" 2>/dev/null | cut -f1)
    log "installing $(basename "$apk") (${size_h:-?}) ..."

    local out
    out=$(mktemp)
    $adb_prefix install -r "$apk" </dev/null >"$out" 2>&1 &
    local pid=$!

    local spin='|/-\' i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r\033[1;34m[droid]\033[0m installing %s ' "${spin:i++%${#spin}:1}" >&2
        sleep 0.2
    done
    wait "$pid"
    local rc=$?
    printf '\r\033[K' >&2  # clear the spinner line

    if [ "$rc" -ne 0 ] || ! grep -q '^Success' "$out"; then
        warn "adb install output:"
        sed 's/^/  /' "$out" >&2
        rm -f "$out"
        die "adb install failed for $(basename "$apk")"
    fi
    rm -f "$out"
    log "installed $(basename "$apk")"
}
