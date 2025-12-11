#!/bin/bash
set -euo pipefail

runner="$1"
runner_real="$(realpath "$runner")"
runner_dir="$(cd "$(dirname "$runner_real")" && pwd -P)"
workspace_root="$runner_dir"
while [[ "$workspace_root" != "/" ]]; do
  if [[ -f "$workspace_root/WORKSPACE" || -f "$workspace_root/WORKSPACE.bazel" ]]; then
    break
  fi
  workspace_root="$(dirname "$workspace_root")"
done

export BUILD_WORKSPACE_DIRECTORY="$workspace_root"
expected="hello from cross-toolchain"

output="$("$runner")"

if [[ "$output" != "$expected" ]]; then
  echo "Expected '$expected' but got '$output'" >&2
  exit 1
fi
