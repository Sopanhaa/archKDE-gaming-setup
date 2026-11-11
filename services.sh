#!/usr/bin/env bash 
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$ROOT_DIR/install.sh" --modules 04 "$@"

#!update 1.0.0
