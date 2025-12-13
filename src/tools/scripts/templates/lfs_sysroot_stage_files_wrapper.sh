#!/bin/bash
set -euo pipefail
# shellcheck disable=SC1083
# This is a template file with placeholders like {src_paths} that get
# replaced by the build system. Shellcheck should not analyze the raw template.

# Determine workspace root. Prefer Bazel-provided path, then runfiles, then search upward.
if [ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]; then
  WORKSPACE_ROOT="$BUILD_WORKSPACE_DIRECTORY"
elif [ -n "${RUNFILES_DIR:-}" ] && [ -d "${RUNFILES_DIR}/_main" ] && { [ -f "${RUNFILES_DIR}/_main/WORKSPACE" ] || [ -f "${RUNFILES_DIR}/_main/WORKSPACE.bazel" ]; }; then
  WORKSPACE_ROOT="${RUNFILES_DIR}/_main"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  CURRENT="$SCRIPT_DIR"
  while [ "$CURRENT" != "/" ]; do
    if [ -f "$CURRENT/WORKSPACE" ] || [ -f "$CURRENT/WORKSPACE.bazel" ]; then
      WORKSPACE_ROOT="$CURRENT"
      break
    fi
    CURRENT="$(dirname "$CURRENT")"
  done
fi

if [ -z "${WORKSPACE_ROOT:-}" ]; then
  echo "Error: could not determine workspace root" >&2
  exit 1
fi

WORKSPACE_ROOT="$(realpath "$WORKSPACE_ROOT")"

LFS_PATH="$WORKSPACE_ROOT/{sysroot_dir}"
HELPER_PATH="$(realpath "$WORKSPACE_ROOT/{helper_abs_path}")"
DEST_REL="{dest_rel}"

LABEL_NAME="{label}"

echo "Staging sysroot files for $LABEL_NAME"
echo "LFS_PATH: $LFS_PATH"
echo "HELPER_PATH: $HELPER_PATH"
echo "DEST_REL: $DEST_REL"

SRC_PATHS=(
{src_paths}
)

ABS_SRCS=()
for src in "${SRC_PATHS[@]}"; do
  # SRC_PATHS entries are workspace-relative (execroot) paths.
  ABS_SRCS+=("$(realpath "$WORKSPACE_ROOT/$src")")
done

sudo "$HELPER_PATH" stage-files "$LFS_PATH" "$DEST_REL" "${ABS_SRCS[@]}"

touch "$(realpath "$WORKSPACE_ROOT/{output_path}")"
echo "Successfully staged sysroot files for $LABEL_NAME"
