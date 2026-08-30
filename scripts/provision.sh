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
    local entry="$1" name source apk
    name=$(echo "$entry" | jq -r '.name')
    source=$(echo "$entry" | jq -r '.source')
    apk="$TMP/$(echo "$name" | tr -cd '[:alnum:]').apk"

    log "installing: $name ($source)"
    case "$source" in
        fdroid) dl_fdroid_apk "$(echo "$entry" | jq -r '.id')" "$apk" ;;
        github) dl_github_release_apk "$(echo "$entry" | jq -r '.id')" "$apk" ;;
        url)    dl_direct_apk "$(echo "$entry" | jq -r '.id')" "$apk" ;;
        *) warn "unknown source '$source' for $name, skipping"; return 1 ;;
    esac
    $ADB install -r "$apk"
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
