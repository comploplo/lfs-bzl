# LFS Bazel Bootstrap

Hybrid build system that drives the Linux From Scratch (LFS) book with Bazel. Bazel handles dependency orchestration and caching; actual builds run via shell/make into a workspace-local sysroot.

## Repository Layout

- `src/` — Bazel workspace, Starlark rules, BUILD files, sysroot under `src/sysroot/`.
- `docs/` — LFS book sources (DocBook).

## Requirements

- Bazel with bzlmod enabled (repo cache defaults to `~/.cache/bazel/_bazel_repo_cache`).
- Host toolchain matching LFS Chapter 2 (gcc, g++, make, etc.).
- Offline builds beyond declared archive fetches.
- Validate host prerequisites: `bazel test //packages/chapter_02:version_check_test` (runs the Chapter 2 version checks).

## Quickstart

```bash
cd src
bazel test  //packages/chapter_02:version_check_test   # host sanity check
bazel build //packages/chapter_05:cross_toolchain
bazel build //packages/hello_world:hello_cross
src/bazel-bin/packages/hello_world/hello_cross
```

Artifacts land in `src/sysroot/` (e.g., `src/sysroot/tools/bin`, `src/sysroot/usr`). The `hello_cross` binary is a simple smoke check using the cross toolchain.

## Toolchains & Cross-Compiling

- Chapter 5 targets (`//packages/chapter_05`) build the cross toolchain into the `src/sysroot/tools` prefix; this toolchain is used for all subsequent target builds.
- Chapter 6 targets (`//packages/chapter_06`) consume that cross toolchain to build the temporary system under `src/sysroot/usr`.
- Bazel runs unsandboxed for these targets so toolchain binaries can write directly into the sysroot.
- Example: `hello_cross` links against the `tools` prefix to validate the cross compiler and headers.

## Development Notes

- Builds run unsandboxed to write into `src/sysroot/`.
- Logs live under the Bazel execroot: `$OUTPUT_BASE/execroot/_main/tracker/logs/`.
- Chapter mapping for packages: Chapter 5 → `src/packages/chapter_05/`; Chapter 6 → `src/packages/chapter_06/`.
