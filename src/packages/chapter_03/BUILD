# Chapter 3 source scaffolding.
#
# Downloads are declared in MODULE.bazel as http_file repos. Here we surface a
# few convenience filegroups for downstream BUILD files without wrapping them in
# extra macros or per-tarball indirection.

load("//tools:lfs_build.bzl", "lfs_package")

# Minimal filegroup that can be used by dependent packages as a shared source
# set (e.g., to copy or inspect archives). This intentionally references the
# http_file targets directly.
filegroup(
    name = "all_ch3_archives",
    srcs = [
        "@bash_src//file",
        "@binutils_src//file",
        "@coreutils_src//file",
        "@diffutils_src//file",
        "@file_src//file",
        "@findutils_src//file",
        "@gawk_src//file",
        "@gcc_src//file",
        "@glibc_src//file",
        "@gmp_src//file",
        "@grep_src//file",
        "@gzip_src//file",
        "@libstdcpp_src//file",
        "@linux_headers_src//file",
        "@m4_src//file",
        "@make_src//file",
        "@mpc_src//file",
        "@mpfr_src//file",
        "@ncurses_src//file",
        "@patch_src//file",
        "@readline_src//file",
        "@sed_src//file",
        "@tar_src//file",
        "@xz_src//file",
    ],
)

# Example scaffolding targets to show expected usage patterns for Chapter 5/6.
# These are placeholders and can be expanded with real configure/build/install
# commands when we wire up the actual toolchain steps.
lfs_package(
    name = "binutils_pass1",
    srcs = ["@binutils_src//file"],
    build_cmd = "echo 'TODO: build binutils pass 1'",
    install_cmd = "echo 'TODO: install binutils pass 1'",
)

lfs_package(
    name = "m4_placeholder",
    srcs = ["@m4_src//file"],
    build_cmd = "echo 'TODO: build m4'",
    configure_cmd = "echo 'TODO: configure m4'",
    install_cmd = "echo 'TODO: install m4'",
)
