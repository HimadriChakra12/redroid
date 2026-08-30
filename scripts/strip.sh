#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require adb

adb_wait_boot "$ADB_PORT"
ADB="adb -s ${ADB_HOST}:${ADB_PORT}"

while read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    log "removing $pkg"
    $ADB shell pm uninstall --user 0 "$pkg" 2>/dev/null \
        || warn "$pkg not present or already removed, skipping"
done < "$DROID_ROOT/config/apps-remove.list"

log "strip done"
