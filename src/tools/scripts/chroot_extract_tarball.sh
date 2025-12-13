#!/bin/bash
set -euo pipefail

tarball="${TARBALL_DEST}/${TARBALL_NAME}"
if [ ! -f "$tarball" ]; then
  echo "Missing tarball: $tarball" >&2
  exit 1
fi

dirname=$(basename "$tarball")
dirname=${dirname%%.tar.*}
tar -xf "$tarball" -C "$TARBALL_DEST"

if [ ! -d "${TARBALL_DEST}/$dirname" ]; then
  echo "Expected directory ${TARBALL_DEST}/$dirname not found after extraction" >&2
  exit 1
fi
