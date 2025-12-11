# LFS Bazel Bootstrap

Hybrid build system that drives the Linux From Scratch (LFS) book with Bazel. Bazel orchestrates dependencies and caching; real builds run via shell/make into a workspace-local sysroot.

## Project Layout

- `src/` – Bazel workspace, rules, package BUILD files, sysroot (`src/sysroot/`).
- `docs/` – LFS book sources (DocBook).
- `tracker/` – status/log notes.
- `tools/` – Starlark rules (`lfs_build.bzl`, providers).

## Requirements

- Bazel (uses bzlmod; repo cache at `~/.cache/bazel/_bazel_repo_cache`).
- Host packages per LFS Chapter 2 (gcc, g++, make, etc.).
- No network during builds beyond fetching declared archives.

## Quickstart

```bash
cd src
bazel build //packages/chapter_05:cross_toolchain
bazel test  //packages/chapter_05:toolchain_smoke_test
```

Artifacts land in `src/sysroot/` (e.g., `src/sysroot/tools/bin`, `src/sysroot/usr`).

Hello world using the cross toolchain:

```bash
bazel build //packages/hello_world:hello_cross
src/bazel-bin/packages/hello_world/hello_cross
```

## Development Notes

- Builds run unsandboxed to write into `src/sysroot/`.
- Logs are under Bazel execroot: `$OUTPUT_BASE/execroot/_main/tracker/logs/`.
- Chapter mapping:
  - Chapter 5: `src/packages/chapter_05/` (cross toolchain).
  - Chapter 6 (in progress): `src/packages/chapter_06/` (temporary tools).

## Pre-commit

Config: `.pre-commit-config.yaml`

```bash
pip install pre-commit        # or: uv tool install pre-commit
pre-commit install
pre-commit run --all-files    # format BUILD/.bzl via buildifier; Markdown via mdformat
```

## Git

Repository initialized; `.gitignore` excludes Bazel outputs, `src/sysroot/`, tracker logs, and pycache.
