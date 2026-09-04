#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require adb; require curl; require jq

adb_wait_boot "$ADB_PORT"
ADB="adb -s ${ADB_HOST}:${ADB_PORT}"

CONF="$DROID_ROOT/config/apps-install.json"
jq -e . "$CONF" >/dev/null || die "$CONF isn't valid JSON"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

install_entry() {
    local entry="$1" name source apk pkg_id
    name=$(echo "$entry" | jq -r '.name')
    source=$(echo "$entry" | jq -r '.source')
    apk="$TMP/$(echo "$name" | tr -cd '[:alnum:]').apk"

    # Package name to check against what's already on the device. For
    # fdroid entries the "id" field already is the package name. For
    # github/url entries there's no package name up front (just a repo path
    # or a raw APK URL) — an optional "package" field can still short-circuit
    # this before downloading anything; otherwise we find out after the
    # download by reading it out of the apk itself.
    pkg_id=$(echo "$entry" | jq -r '.package // empty')
    if [ -z "$pkg_id" ] && [ "$source" = "fdroid" ]; then
        pkg_id=$(echo "$entry" | jq -r '.id')
    fi

    if [ -n "$pkg_id" ] && is_pkg_installed "$ADB" "$pkg_id"; then
        log "$name ($pkg_id) is already installed, skipping"
        return 0
    fi

    log "installing: $name ($source)"
    case "$source" in
        fdroid) dl_fdroid_apk "$(echo "$entry" | jq -r '.id')" "$apk" ;;
        github) dl_github_release_apk "$(echo "$entry" | jq -r '.id')" "$apk" ;;
        url)    dl_direct_apk "$(echo "$entry" | jq -r '.id')" "$apk" ;;
        *) warn "unknown source '$source' for $name, skipping"; return 1 ;;
    esac

    # We didn't know the package name before downloading (github/url with
    # no explicit "package" field) — now that we have the apk, read it out
    # and check again before paying the install/Play-Protect cost.
    if [ -z "$pkg_id" ]; then
        pkg_id=$(extract_apk_package "$apk")
        if [ -n "$pkg_id" ]; then
            log "$name resolved to package $pkg_id"
            if is_pkg_installed "$ADB" "$pkg_id"; then
                log "$name ($pkg_id) is already installed, skipping install"
                return 0
            fi
        else
            warn "couldn't determine package name for $name (aapt/aapt2 not found or apk unparseable) — installing without a check"
        fi
    fi

    adb_install_with_progress "$ADB" "$apk"
}

while IFS= read -r entry; do
    name=$(echo "$entry" | jq -r '.name')
    # Each entry runs in its own subshell: a die() or curl failure inside
    # one entry (e.g. an unfilled placeholder URL) only kills that entry,
    # not the whole provisioning run.
    ( install_entry "$entry" ) || warn "install failed for $name, skipping it"
done < <(jq -c '.[]' "$CONF")

touch "$DROID_DIR/.provisioned"
log "provisioning done"
