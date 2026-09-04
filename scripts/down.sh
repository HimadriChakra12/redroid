#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require docker

docker stop "$CONTAINER_NAME" >/dev/null 2>&1 && log "stopped $CONTAINER_NAME" \
    || warn "$CONTAINER_NAME wasn't running"
