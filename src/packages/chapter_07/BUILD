"""
Chapter 7: Entering the Chroot Environment (Rootless Podman Worker)

Builds essential packages inside the chroot environment using the rootless
Podman worker system. All builds run without sudo.

This chapter builds 6 packages:
- gettext (i18n tools)
- bison (parser generator)
- perl (scripting language)
- python (programming language)
- texinfo (documentation system)
- util-linux (system utilities)
"""

load("//tools:lfs_package.bzl", "lfs_package")
load("//tools:lfs_script.bzl", "lfs_script")
load("//tools:lfs_toolchain.bzl", "lfs_toolchain")

package(default_visibility = ["//visibility:public"])

# --------------------------------------------------------------------------- #
# Chapter 7 preparation steps (Podman worker - no sudo required)
# --------------------------------------------------------------------------- #

# Create directory structure inside chroot
lfs_script(
    name = "chroot_create_dirs",
    script = """
        # Matches docs/lfs-book/chapter07/creatingdirs.xml (System V)

        # Create essential symlinks (/bin -> usr/bin, etc.)
        # These must exist before running configure scripts. Relative targets:
        # inside the chroot they mean /usr/*, and resolved from the macOS host
        # they stay inside the sysroot instead of escaping to the host's /usr.
        ln -snfv usr/bin /bin
        ln -snfv usr/sbin /sbin
        ln -snfv usr/lib /lib
        case $(uname -m) in
          x86_64) ln -snfv usr/lib /lib64 ;;
        esac

        mkdir -pv /{boot,home,mnt,opt,srv}
        mkdir -pv /etc/{opt,sysconfig}
        mkdir -pv /lib/firmware
        mkdir -pv /media/{floppy,cdrom}
        mkdir -pv /usr/{,local/}{include,src}
        mkdir -pv /usr/lib/locale
        mkdir -pv /usr/local/{bin,lib,sbin}
        mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
        mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
        mkdir -pv /usr/{,local/}share/man/man{1..8}
        mkdir -pv /var/{cache,local,log,mail,opt,spool}
        mkdir -pv /var/lib/{color,misc,locate}
        mkdir -pv /sources
        ln -sfv /run /var/run
        ln -sfv /run/lock /var/lock
        install -dv -m 0750 /root
        install -dv -m 1777 /tmp /var/tmp
    """,
    deps = ["//packages/chapter_06"],
)

# Seed essential files (/etc/passwd, /etc/group, etc.)
lfs_script(
    name = "chroot_seed_files",
    script = """
        # Matches docs/lfs-book/chapter07/createfiles.xml (systemd edition)

        # Ensure /bin/sh -> bash (ch6 already created it; -sf keeps this rerun-safe).
        # No /bin/bash symlink: with merged-/usr /bin is /usr/bin, so /bin/bash IS
        # the real binary and `ln` would try to link it onto itself ("same file").
        ln -sfv /usr/bin/bash /bin/sh

        # Create /etc/mtab symlink (-snf for rerun-safety)
        ln -snfv /proc/self/mounts /etc/mtab

        # Create /etc/hosts
        cat > /etc/hosts <<EOF
127.0.0.1  localhost $(hostname)
::1        localhost
EOF

        # Create /etc/passwd
        cat > /etc/passwd <<'EOF'
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/usr/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/usr/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/usr/bin/false
systemd-network:x:76:76:systemd Network Management:/:/usr/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/usr/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/usr/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
systemd-oom:x:81:81:systemd Out Of Memory Daemon:/:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF

        # Create /etc/group
        cat > /etc/group <<'EOF'
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
kvm:x:61:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
uuidd:x:80:
systemd-oom:x:81:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF

        # Add tester user
        echo "tester:x:101:101::/home/tester:/bin/bash" >> /etc/passwd
        echo "tester:x:101:" >> /etc/group
        install -o tester -d /home/tester

        # Create log files
        touch /var/log/{btmp,lastlog,faillog,wtmp}
        chgrp -v utmp /var/log/lastlog
        chmod -v 664 /var/log/lastlog
        chmod -v 600 /var/log/btmp
    """,
    deps = [
        ":chroot_create_dirs",
        "//packages/chapter_06",
    ],
)

# Cleanup temporary files before building packages
lfs_script(
    name = "chroot_cleanup_tmp",
    script = """
        rm -rf /tmp/* /var/tmp/*
    """,
    deps = [
        ":chroot_seed_files",
        "//packages/chapter_06",
    ],
)

# Aggregate preparation target
filegroup(
    name = "chroot_prepare",
    srcs = [
        ":chroot_cleanup_tmp",
        ":chroot_create_dirs",
        ":chroot_seed_files",
    ],
)

# Toolchain representing the Chapter 7 chroot-built base system (/usr/bin).
# Downstream chapters can depend on this instead of the temporary tools toolchain.
lfs_toolchain(
    name = "chroot_base_toolchain",
    bin_path = "/usr/bin:/usr/sbin:/bin:/sbin",
    env = {
        # Environment is set by Podman worker
        # This is mainly for documentation/dependency tracking
    },
    visibility = ["//visibility:public"],
    deps = [
        # All six ch7 packages: util_linux alone does not dominate the
        # chapter (bison/python/texinfo are not upstream of it), so anything
        # gating on this target could otherwise start before ch7 is complete.
        ":bison",
        ":gettext",
        ":perl",
        ":python",
        ":texinfo",
        ":util_linux",
    ],
)

# --------------------------------------------------------------------------- #
# Chapter 7 packages (built inside Podman worker - no sudo required)
#
# PARALLELISM: These packages have minimal inter-dependencies and can build
# in parallel. The Podman worker handles concurrent builds safely.
#
# Dependency strategy:
# - Gettext builds first (provides i18n tools that may be used by others)
# - All other packages can build in parallel after gettext
# --------------------------------------------------------------------------- #

# Gettext - i18n tools (built first, provides msgfmt for others)
lfs_package(
    name = "gettext",
    srcs = ["@gettext_src//file"],
    build_cmd = "make -j$(nproc)",
    configure_cmd = "./configure --disable-shared",
    install_cmd = """
        cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
    """,
    phase = "chroot",
    deps = [":chroot_prepare"],
)

# Bison - parser generator
lfs_package(
    name = "bison",
    srcs = ["@bison_src//file"],
    build_cmd = "make -j$(nproc)",
    configure_cmd = "./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2",
    install_cmd = "make install",
    phase = "chroot",
    deps = [
        ":chroot_prepare",
        ":gettext",  # Wait for gettext i18n tools
    ],
)

# Perl - scripting language with shared library support
lfs_package(
    name = "perl",
    srcs = ["@perl_src//file"],
    build_cmd = "make -j$(nproc)",
    configure_cmd = """
        sh Configure -des -D prefix=/usr -D vendorprefix=/usr -D useshrplib \\
          -Dprivlib=/usr/lib/perl5/5.42/core_perl \\
          -Darchlib=/usr/lib/perl5/5.42/core_perl \\
          -Dsitelib=/usr/lib/perl5/5.42/site_perl \\
          -Dsitearch=/usr/lib/perl5/5.42/site_perl \\
          -Dvendorlib=/usr/lib/perl5/5.42/vendor_perl \\
          -Dvendorarch=/usr/lib/perl5/5.42/vendor_perl
    """,
    install_cmd = "make install",
    phase = "chroot",
    deps = [
        ":chroot_prepare",
        ":gettext",  # Wait for gettext i18n tools
    ],
)

# Python - programming language with shared support
lfs_package(
    name = "python",
    srcs = ["@python_src//file"],
    build_cmd = "make -j$(nproc)",
    configure_cmd = "./configure --prefix=/usr --enable-shared --without-ensurepip --without-static-libpython",
    install_cmd = "make install",
    phase = "chroot",
    deps = [
        ":chroot_prepare",
        ":gettext",  # Wait for gettext i18n tools
    ],
)

# Texinfo - documentation system
lfs_package(
    name = "texinfo",
    srcs = ["@texinfo_src//file"],
    build_cmd = "make -j$(nproc)",
    configure_cmd = "./configure --prefix=/usr",
    install_cmd = "make install",
    phase = "chroot",
    deps = [
        ":chroot_prepare",
        ":gettext",
        ":perl",
    ],
)

# Util-linux - system utilities (mount, lsblk, fdisk, etc.)
lfs_package(
    name = "util_linux",
    srcs = ["@util_linux_src//file"],
    build_cmd = "make -j$(nproc)",
    configure_cmd = """
        mkdir -pv /var/lib/hwclock
        ./configure --libdir=/usr/lib \\
          --runstatedir=/run \\
          --disable-chfn-chsh \\
          --disable-login \\
          --disable-nologin \\
          --disable-su \\
          --disable-setpriv \\
          --disable-runuser \\
          --disable-pylibmount \\
          --disable-static \\
          --disable-liblastlog2 \\
          --without-python \\
          ADJTIME_PATH=/var/lib/hwclock/adjtime \\
          --docdir=/usr/share/doc/util-linux-2.41.3
    """,
    install_cmd = "make install",
    phase = "chroot",
    deps = [
        ":chroot_prepare",
        ":gettext",  # Wait for gettext i18n tools
        ":perl",  # Needed for ./tools/all_syscalls script during build
    ],
)

# Convenience aggregate to build all Chapter 7 packages
filegroup(
    name = "chapter_07",
    srcs = [
        ":bison",
        ":gettext",
        ":perl",
        ":python",
        ":texinfo",
        ":util_linux",
    ],
)

# Chapter 7.14 cleanup (optional but recommended)
lfs_script(
    name = "chroot_cleanup",
    script = """
        # Remove libtool archive files
        find /usr/{lib,libexec} -name '*.la' -delete
        # Remove Chapter 6 tools directory if it exists
        rm -rf /tools
        # Clean temporary files
        rm -rf /tmp/* /var/tmp/*
        # Note: Skipping /usr/share/{info,man,doc} cleanup due to
        # permission issues with some man pages even when running as root
    """,
    deps = [":chapter_07"],
)

# Quick validation of core Chapter 7 toolchain inside chroot
lfs_script(
    name = "chroot_smoke_versions",
    script = """
        bison --version | head -1
        msgfmt --version | head -1
        perl -V:version
        python3 -V
        info --version | head -1
        lsblk --version | head -1
    """,
    deps = [":chapter_07"],
)
