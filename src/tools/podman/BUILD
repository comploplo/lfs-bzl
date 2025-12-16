"""
Podman Container Worker for LFS Chroot Builds

This package provides the rootless Podman container and Bazel JSON worker
infrastructure for executing LFS Chapter 7-8+ builds without sudo.
"""

load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

package(default_visibility = ["//visibility:public"])

# Build the container image
# Usage:
#   bazel run //tools/podman:container_image        # Build the image
#   bazel run //tools/podman:container_image -- -i  # Build and launch interactive shell
sh_binary(
    name = "container_image",
    srcs = ["scripts/build_container.sh"],
    data = [
        "Containerfile",
        "scripts/worker.py",
    ],
    tags = [
        "local",
        "manual",
    ],
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
# Requires container to be pre-built: bazel run //tools/podman:container_image
sh_test(
    name = "worker_smoke_test",
    srcs = ["scripts/worker_smoke_test.sh"],
    args = ["$(location :worker_launcher)"],
    data = [":worker_launcher"],
    tags = [
        "local",
        "manual",
        "requires-podman",
    ],
)

# Utility script to cleanup orphaned worker containers
# Usage: bazel run //tools/podman:cleanup_orphaned -- --force
sh_binary(
    name = "cleanup_orphaned",
    srcs = ["scripts/cleanup_orphaned.sh"],
    tags = ["manual"],
)
