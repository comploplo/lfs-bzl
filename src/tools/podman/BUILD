"""
Podman Container Worker for LFS Chroot Builds

This package provides the rootless Podman container and Bazel JSON worker
infrastructure for executing LFS Chapter 7-8+ builds without sudo.
"""

load("@rules_python//python:defs.bzl", "py_library", "py_test")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

package(default_visibility = ["//visibility:public"])

# Build the container image
# Usage:
#   bazel run //tools/podman:container_image        # Build the image
#   bazel run //tools/podman:container_image -- -i  # Build and launch interactive shell
sh_binary(
    name = "container_image",
    srcs = ["//tools/scripts:build_container.sh"],
    data = [
        "Containerfile",
        "worker.py",
    ],
    tags = [
        "local",
        "manual",
    ],
)

py_library(
    name = "worker_lib",
    srcs = ["worker.py"],
)

# Generate worker launcher script from template
# NOTE: This no longer depends on :container_image to avoid cache invalidation.
# The container must be pre-built with: bazel run //tools/podman:container_image
genrule(
    name = "worker_launcher",
    srcs = ["//tools/scripts/templates:worker_launcher_template"],
    outs = ["worker_launcher.sh"],
    cmd = """
        sed -e 's|{SYSROOT_REL}|sysroot|g' \
            $(location //tools/scripts/templates:worker_launcher_template) > $(OUTS)
        chmod +x $(OUTS)
    """,
    executable = True,
)

# Smoke test for worker
py_test(
    name = "worker_test",
    srcs = ["worker_test.py"],
    tags = ["small"],
    deps = [":worker_lib"],
)

# Utility script to cleanup orphaned worker containers
# Usage: bazel run //tools/podman:cleanup_orphaned -- --force
sh_binary(
    name = "cleanup_orphaned",
    srcs = ["//tools/scripts:cleanup_orphaned.sh"],
    tags = ["manual"],
)
