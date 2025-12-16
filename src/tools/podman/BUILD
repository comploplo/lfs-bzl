"""
Podman Container Worker for LFS Chroot Builds

This package provides the rootless Podman container and Bazel JSON worker
infrastructure for executing LFS Chapter 7-8+ builds without sudo.
"""

load("@rules_shell//shell:sh_test.bzl", "sh_test")

package(default_visibility = ["//visibility:public"])

# Export flagfile template for worker arguments
exports_files(
    [
        "scripts/worker_flagfile.tpl",
    ],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "worker_flagfile_template",
    srcs = ["scripts/worker_flagfile.tpl"],
)

# Build and save the container image
genrule(
    name = "container_image",
    srcs = [
        "Containerfile",
        "scripts/worker.py",
    ],
    outs = ["lfs-builder.tar"],
    cmd = """
        OUTPUT_TAR="$$(realpath $(OUTS))"
        cd $$(dirname $(location Containerfile))
        podman build --no-cache -t lfs-builder:bookworm -f Containerfile .
        podman save -o "$$OUTPUT_TAR" lfs-builder:bookworm
    """,
    tags = [
        "local",
        "manual",
    ],
)

# Generate worker launcher script from template
genrule(
    name = "worker_launcher",
    srcs = [
        "scripts/worker_launcher.sh.tpl",
        ":container_image",
    ],
    outs = ["worker_launcher.sh"],
    cmd = """
        sed -e 's|{CONTAINER_TAR}|$(location :container_image)|g' \
            -e 's|{SYSROOT_REL}|sysroot|g' \
            $(location scripts/worker_launcher.sh.tpl) > $(OUTS)
        chmod +x $(OUTS)
    """,
    executable = True,
)

# Smoke test for worker
sh_test(
    name = "worker_smoke_test",
    srcs = ["scripts/worker_smoke_test.sh"],
    args = [
        "$(location :worker_launcher)",
        "$(location :container_image)",
    ],
    data = [
        ":container_image",
        ":worker_launcher",
    ],
    tags = [
        "local",
        "manual",
        "requires-podman",
    ],
)
