load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//tools:lfs_build.bzl", "lfs_chroot_command", "lfs_chroot_extract_tarball", "lfs_chroot_step", "lfs_package", "lfs_toolchain")

package(default_visibility = ["//visibility:public"])

lfs_chroot_command(
    name = "test_chroot_echo",
    chroot_helper = "//tools:lfs_chroot_helper_script",
    cmd = """
echo "Hello from inside the chroot!"
/bin/bash --version || true # Check for bash, allow failure
id || true
""",
    lfs_sysroot = "//:lfs_sysroot_files",
    tags = [
        "manual",
        "requires-sudo",
    ],
    toolchain = "//packages/chapter_06:temp_tools_toolchain",
    visibility = ["//visibility:public"],
)

sh_test(
    name = "chroot_smoke_test",
    srcs = ["chroot_smoke_test.sh"],
    args = [
        "$(location test-chroot.sh)",
        "$(location //tools:lfs_chroot_helper_script)",
        "$(location //:lfs_sysroot_files)",
    ],
    data = [
        "test-chroot.sh",  # executed inside chroot
        "//:lfs_sysroot_files",
        "//tools:lfs_chroot_helper_script",
    ],
    tags = [
        "manual",
        "requires-sudo",
    ],
    visibility = ["//visibility:public"],
)

# --------------------------------------------------------------------------- #
# Chapter 7 prep steps (filesystem layout, ownership, cleanup)
# --------------------------------------------------------------------------- #

lfs_package(
    name = "stage_ch7_sources",
    srcs = [
        "@bison_src//file",
        "@gettext_src//file",
        "@perl_src//file",
        "@python_src//file",
        "@texinfo_src//file",
        "@util_linux_src//file",
    ],
    build_cmd = "true",
    install_cmd = """
        mkdir -p $LFS/sources
        shopt -s nullglob
        for f in "$EXECROOT"/external/*/*.tar.xz "$EXECROOT"/external/*/*.tar.gz "$EXECROOT"/external/*/*.tar.bz2; do
          [ -f "$f" ] || continue
          cp -v "$f" $LFS/sources/
        done
    """,
)

lfs_chroot_step(
    name = "chroot_create_dirs",
    cmd = """
set -euo pipefail
install -dv {/boot,/home,/mnt,/opt,/srv}
install -dv /etc/{opt,sysconfig}
install -dv /lib/firmware
install -dv /media/{floppy,cdrom}
install -dv /usr/{,local/}{bin,lib,sbin}
install -dv /usr/local/share/{color,dict,doc,info,locale,man}
install -dv /usr/local/share/{misc,terminfo,zoneinfo}
install -dv /usr/local/{src,include}
install -dv /usr/share/{color,dict,doc,info,locale,man}
install -dv /usr/share/{misc,terminfo,zoneinfo}
install -dv /usr/{,local/}share/man/man{1..8}
install -dv /var/{cache,local,log,mail,opt,spool}
install -dv /var/lib/{color,misc,locate}
ln -sf /run /var/run
ln -sf /run/lock /var/lock
install -dv /root
install -dv -m 1777 /tmp /var/tmp
""",
)

lfs_chroot_step(
    name = "chroot_seed_files",
    cmd = """
set -euo pipefail
ln -sf /proc/self/mounts /etc/mtab
cat >/etc/hosts <<'EOF'
127.0.0.1 localhost
::1       localhost
127.0.1.1 lfs.localdomain lfs
EOF
cat >/etc/passwd <<'EOF'
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
uuidd:x:999:999:uuidd:/var/lib/uuidd:/usr/bin/false
EOF
cat >/etc/group <<'EOF'
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tty:x:4:
tape:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
cdrom:x:13:
games:x:14:
users:x:999:
adm:x:16:
systemd-journal:x:23:
systemd-network:x:192:
systemd-resolve:x:193:
systemd-timesync:x:194:
systemd-coredump:x:999:
nobody:x:65534:
EOF
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog || true
chmod -v 664 /var/log/lastlog
chmod -v 600 /var/log/btmp
""",
)

lfs_chroot_step(
    name = "chroot_chown_root",
    cmd = """
set -euo pipefail
chown -R root:root /{bin,etc,lib,sbin,usr,lib64,var,tools}
""",
    deps = [":chroot_seed_files"],
)

lfs_chroot_step(
    name = "chroot_cleanup_tmp",
    cmd = """
set -euo pipefail
rm -rf /tmp/* /var/tmp/* || true
""",
)

lfs_chroot_step(
    name = "chroot_prepare",
    cmd = "true",
    deps = [
        ":chroot_chown_root",
        ":chroot_create_dirs",
        ":chroot_seed_files",
        ":stage_ch7_sources",
    ],
)

# Toolchain representing the Chapter 7 chroot-built base system (/usr/bin).
# Downstream chapters can depend on this instead of the temporary tools toolchain.
lfs_toolchain(
    name = "chroot_base_toolchain",
    bin_path = "/usr/bin:/usr/sbin:/bin:/sbin",
    env = {
        "CC": "gcc",
        "CXX": "g++",
        "LFS_TGT": "x86_64-lfs-linux-gnu",
    },
    visibility = ["//visibility:public"],
)

# --------------------------------------------------------------------------- #
# Chapter 7 package stubs (chroot builds using temp tools toolchain)
# TODO: add sources to MODULE.bazel and real build commands.
# --------------------------------------------------------------------------- #

lfs_chroot_step(
    name = "bison",
    cmd = """
set -euo pipefail
cd /sources/bison-3.8.2
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
make -j$(nproc)
make install
""",
    deps = [":extract_bison"],
)

lfs_chroot_extract_tarball(
    name = "extract_bison",
    tarball_name = "bison-3.8.2.tar.xz",
    deps = [":stage_ch7_sources"],
)

lfs_chroot_step(
    name = "gettext",
    cmd = """
set -euo pipefail
cd /sources/gettext-0.22.5
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/gettext-0.22.5
make -j$(nproc)
make install
""",
    deps = [":extract_gettext"],
)

lfs_chroot_extract_tarball(
    name = "extract_gettext",
    tarball_name = "gettext-0.22.5.tar.xz",
    deps = [":stage_ch7_sources"],
)

lfs_chroot_step(
    name = "perl",
    cmd = """
set -euo pipefail
cd /sources/perl-5.40.0
sh Configure -des -Dprefix=/usr -Dvendorprefix=/usr \\
  -Dprivlib=/usr/lib/perl5/5.40/core_perl \\
  -Darchlib=/usr/lib/perl5/5.40/core_perl \\
  -Dsitelib=/usr/lib/perl5/5.40/site_perl \\
  -Dsitearch=/usr/lib/perl5/5.40/site_perl \\
  -Dvendorlib=/usr/lib/perl5/5.40/vendor_perl \\
  -Dvendorarch=/usr/lib/perl5/5.40/vendor_perl
make -j$(nproc)
make install
""",
    deps = [":extract_perl"],
)

lfs_chroot_extract_tarball(
    name = "extract_perl",
    tarball_name = "perl-5.40.0.tar.xz",
    deps = [":stage_ch7_sources"],
)

lfs_chroot_step(
    name = "python",
    cmd = """
set -euo pipefail
cd /sources/Python-3.12.4
./configure --prefix=/usr --enable-shared --with-ensurepip=no --enable-optimizations
make -j$(nproc)
make install
ln -sf python3 /usr/bin/python
""",
    deps = [":extract_python"],
)

lfs_chroot_extract_tarball(
    name = "extract_python",
    tarball_name = "Python-3.12.4.tar.xz",
    deps = [":stage_ch7_sources"],
)

lfs_chroot_step(
    name = "texinfo",
    cmd = """
set -euo pipefail
cd /sources/texinfo-7.1
./configure --prefix=/usr
make -j$(nproc)
make install
make TEXMF=/usr/share/texmf install-tex
""",
    deps = [":extract_texinfo"],
)

lfs_chroot_extract_tarball(
    name = "extract_texinfo",
    tarball_name = "texinfo-7.1.tar.xz",
    deps = [":stage_ch7_sources"],
)

lfs_chroot_step(
    name = "util_linux",
    cmd = """
set -euo pipefail
cd /sources/util-linux-2.40.2
./configure \\
  ADJTIME_PATH=/var/lib/hwclock/adjtime \\
  --prefix=/usr \\
  --bindir=/usr/bin \\
  --sbindir=/usr/sbin \\
  --libdir=/usr/lib \\
  --sysconfdir=/etc \\
  --docdir=/usr/share/doc/util-linux-2.40.2 \\
  --runstatedir=/run \\
  --disable-chfn-chsh \\
  --disable-login \\
  --disable-nologin \\
  --disable-su \\
  --disable-setpriv \\
  --disable-runuser \\
  --disable-pylibmount \\
  --disable-static \\
  --without-python \\
  --without-systemd \\
  --with-usr
make -j$(nproc)
make install
""",
    deps = [":extract_util_linux"],
)

lfs_chroot_extract_tarball(
    name = "extract_util_linux",
    tarball_name = "util-linux-2.40.2.tar.xz",
    deps = [":stage_ch7_sources"],
)

# Convenience aggregate to run all Chapter 7 builds in order (manual/sudo).
lfs_chroot_step(
    name = "chroot_toolchain_phase",
    cmd = "true",
    deps = [
        ":bison",
        ":chroot_cleanup_tmp",
        ":chroot_prepare",
        ":extract_bison",
        ":extract_gettext",
        ":extract_perl",
        ":extract_python",
        ":extract_texinfo",
        ":extract_util_linux",
        ":gettext",
        ":perl",
        ":python",
        ":texinfo",
        ":util_linux",
    ],
)

# Quick validation of core Chapter 7 toolchain inside chroot.
lfs_chroot_step(
    name = "chroot_smoke_versions",
    cmd = """
set -euo pipefail
bison --version | head -1
gettext --version | head -1
perl -V:version
python3 -V
info --version | head -1
lsblk --version | head -1
""",
    tags = [
        "manual",
        "requires-sudo",
    ],
    deps = [
        ":chroot_toolchain_phase",
    ],
)
