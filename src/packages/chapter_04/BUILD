"""
Chapter 4 scaffolding using plain Bazel primitives.

Goals:
- Represent the LFS filesystem toplevel as a filegroup.
- Provide genrules that lay out the expected directory tree and starter
  environment markers without introducing custom macros.
"""

package(default_visibility = ["//visibility:public"])

# Directory skeleton for $LFS. The output is a directory artifact shaped like
# the eventual sysroot root (tools/, sources/, build/, etc).
genrule(
    name = "lfs_root_skeleton",
    outs = ["lfs_root_layout.tar"],
    cmd = """
        TMPDIR="$(@D)/lfs_root_layout"
        rm -rf "$$TMPDIR"
        mkdir -p "$$TMPDIR"/{tools,build,sources,usr,var,tmp,dev,proc,run,sys}
        touch "$$TMPDIR"/.lfs_root_marker
        tar -cf "$@" -C "$(@D)" lfs_root_layout
    """,
)

# Convenience filegroup to refer to the root skeleton as a single target.
filegroup(
    name = "lfs_root",
    srcs = [":lfs_root_skeleton"],
)

# Starter env file to mirror Chapter 4 exports. This can be consumed by later
# rules (or copied into sysroot) but remains a simple genrule artifact.
genrule(
    name = "lfs_env_exports",
    outs = ["lfs_env.sh"],
    cmd = """
        cat >"$@" <<'EOF'
export LFS="$$(pwd)/sysroot"
export LC_ALL=POSIX
export LFS_TGT=x86_64-lfs-linux-gnu
export PATH="$$LFS/tools/bin:$$PATH"
EOF
    """,
)
