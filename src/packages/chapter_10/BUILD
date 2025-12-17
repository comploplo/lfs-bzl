"""
Chapter 10: Making the LFS System Bootable

This chapter involves:
1. Building the Linux Kernel
2. Configuring the GRUB bootloader
"""

load("//tools:lfs_package.bzl", "lfs_package")
load("//tools:lfs_script.bzl", "lfs_script")

package(default_visibility = ["//visibility:public"])

# --------------------------------------------------------------------------- #
# Linux Kernel Configuration
# --------------------------------------------------------------------------- #

lfs_script(
    name = "kernel_config",
    script = """
        # Create /etc/modprobe.d/usb.conf for USB module load order
        install -v -m755 -d /etc/modprobe.d
        cat > /etc/modprobe.d/usb.conf << "EOF"
# Begin /etc/modprobe.d/usb.conf

install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true

# End /etc/modprobe.d/usb.conf
EOF

        # Ensure /boot exists
        mkdir -pv /boot
    """,
    deps = ["//packages/chapter_08:toolchain"],
)

# --------------------------------------------------------------------------- #
# Linux Kernel
# --------------------------------------------------------------------------- #

lfs_package(
    name = "kernel",
    srcs = ["@linux_headers_src//file"],
    build_cmd = """
        make mrproper
        make defconfig

        # Enable required systemd options
        scripts/config --enable CONFIG_PSI
        scripts/config --disable CONFIG_PSI_DEFAULT_DISABLED
        scripts/config --enable CONFIG_CGROUPS
        scripts/config --enable CONFIG_MEMCG
        scripts/config --enable CONFIG_CGROUP_SCHED
        scripts/config --disable CONFIG_RT_GROUP_SCHED
        scripts/config --enable CONFIG_RELOCATABLE
        scripts/config --enable CONFIG_RANDOMIZE_BASE
        scripts/config --enable CONFIG_STACKPROTECTOR
        scripts/config --enable CONFIG_STACKPROTECTOR_STRONG
        scripts/config --enable CONFIG_NET
        scripts/config --enable CONFIG_INET
        scripts/config --enable CONFIG_IPV6
        scripts/config --disable CONFIG_UEVENT_HELPER
        scripts/config --enable CONFIG_DEVTMPFS
        scripts/config --enable CONFIG_DEVTMPFS_MOUNT
        scripts/config --enable CONFIG_FW_LOADER
        scripts/config --disable CONFIG_FW_LOADER_USER_HELPER
        scripts/config --enable CONFIG_DMIID
        scripts/config --enable CONFIG_INOTIFY_USER
        scripts/config --enable CONFIG_TMPFS
        scripts/config --enable CONFIG_TMPFS_POSIX_ACL

        # Disable warnings-as-errors to avoid build failures
        scripts/config --disable CONFIG_WERROR

        # Resolve any dependency issues
        make olddefconfig

        # Build kernel and modules
        make -j$(nproc) bzImage
        make -j$(nproc) modules
    """,
    configure_cmd = "true",
    install_cmd = """
        make modules_install

        # Install kernel image
        cp -iv arch/x86/boot/bzImage /boot/vmlinuz-6.10.5-lfs-12.2

        # Install symbol map and config
        cp -iv System.map /boot/System.map-6.10.5
        cp -iv .config /boot/config-6.10.5

        # Install documentation
        install -d /usr/share/doc/linux-6.10.5
        cp -r Documentation/* /usr/share/doc/linux-6.10.5
    """,
    phase = "chroot",
    deps = [
        ":kernel_config",
        "//packages/chapter_08:bc",
        "//packages/chapter_08:bison",
        "//packages/chapter_08:flex",
        "//packages/chapter_08:kmod",
        "//packages/chapter_08:libelf",
        "//packages/chapter_08:openssl",
        "//packages/chapter_08:perl",
        "//packages/chapter_08:python",
        "//packages/chapter_08:toolchain",
    ],
)

# --------------------------------------------------------------------------- #
# GRUB Configuration
# --------------------------------------------------------------------------- #

lfs_script(
    name = "grub_config",
    script = """
        mkdir -pv /boot/grub

        cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod ext2
set root=(hd0,1)

menuentry "GNU/Linux, Linux 6.10.5-lfs-12.2" {
    linux   /boot/vmlinuz-6.10.5-lfs-12.2 root=/dev/sda1 ro
}
EOF
    """,
    deps = [":kernel"],
)

# --------------------------------------------------------------------------- #
# Chapter 10 Aggregate
# --------------------------------------------------------------------------- #

filegroup(
    name = "chapter_10",
    srcs = [
        ":grub_config",
        ":kernel",
    ],
)
