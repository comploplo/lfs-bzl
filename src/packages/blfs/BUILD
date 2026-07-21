"""
BLFS: Beyond Linux From Scratch (selected packages)

Post-LFS packages that make the booted system usable: remote access
(openssh, sudo) and fetching/building software from the network
(curl, git, CA certificates). Recipes follow the BLFS book; docs that
need asciidoc/xmlto are skipped.
"""

load("//tools:lfs_package.bzl", "lfs_package")
load("//tools:lfs_script.bzl", "lfs_script")

package(default_visibility = ["//visibility:public"])

# Mozilla CA bundle (curl.se snapshot) at OpenSSL's default CAfile path.
# Replaces the full BLFS make-ca/p11-kit chain: openssl, curl and git all
# verify TLS against /etc/ssl/cert.pem.
lfs_package(
    name = "ca_certificates",
    srcs = ["@cacert_src//file"],
    build_cmd = "true",
    configure_cmd = "true",
    install_cmd = "install -v -m644 cacert-2026-05-14.pem /etc/ssl/cert.pem",
    phase = "chroot",
    deps = ["//packages/chapter_08:openssl"],
)

lfs_package(
    name = "sudo",
    srcs = ["@sudo_src//file"],
    build_cmd = "make -j$(nproc)",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --libexecdir=/usr/lib \\
            --with-secure-path \\
            --with-env-editor \\
            --docdir=/usr/share/doc/sudo-1.9.17p2 \\
            --with-passprompt="[sudo] password for %p: "
    """,
    install_cmd = """
        make install

        cat > /etc/sudoers.d/00-wheel << "EOF"
# User privilege specification
root ALL=(ALL) ALL
%wheel ALL=(ALL) ALL
EOF
    """,
    phase = "chroot",
    deps = [
        "//packages/chapter_08:openssl",
        "//packages/chapter_08:toolchain",
        "//packages/chapter_08:zlib",
    ],
)

# The sshd privilege-separation user/group must exist before `make install`
# runs `ssh-keygen -A` and sshd sanity checks. Plain writes instead of
# groupadd/useradd: shadow's commonio locking breaks on virtiofs (same
# workaround as the coreutils test setup).
lfs_script(
    name = "sshd_user",
    script = """
        grep -q '^sshd:' /etc/group  || echo "sshd:x:50:" >> /etc/group
        grep -q '^sshd:' /etc/passwd || \\
            echo "sshd:x:50:50:sshd PrivSep:/var/lib/sshd:/bin/false" >> /etc/passwd
        install -v -g sys -m700 -d /var/lib/sshd
    """,
    deps = ["//packages/chapter_08:toolchain"],
)

lfs_package(
    name = "openssh",
    srcs = ["@openssh_src//file"],
    build_cmd = "make -j$(nproc)",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --sysconfdir=/etc/ssh \\
            --with-privsep-path=/var/lib/sshd \\
            --with-default-path=/usr/bin \\
            --with-superuser-path=/usr/sbin:/usr/bin \\
            --with-pid-dir=/run
    """,
    install_cmd = """
        make install
        install -v -m755 contrib/ssh-copy-id /usr/bin
        install -v -m644 contrib/ssh-copy-id.1 /usr/share/man/man1

        # BLFS ships this unit via its systemd-units tarball; written inline
        # here to keep the package self-contained.
        cat > /usr/lib/systemd/system/sshd.service << "EOF"
[Unit]
Description=OpenSSH Daemon
Wants=sshdgenkeys.service
After=network.target

[Service]
ExecStart=/usr/sbin/sshd -D
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
RestartSec=42s

[Install]
WantedBy=multi-user.target
EOF
    """,
    phase = "chroot",
    deps = [
        ":sshd_user",
        "//packages/chapter_08:openssl",
        "//packages/chapter_08:zlib",
    ],
)

lfs_package(
    name = "curl",
    srcs = ["@curl_src//file"],
    build_cmd = "make -j$(nproc)",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --disable-static \\
            --with-openssl \\
            --without-libpsl \\
            --enable-threaded-resolver \\
            --with-ca-bundle=/etc/ssl/cert.pem
    """,
    install_cmd = "make install",
    phase = "chroot",
    deps = [
        ":ca_certificates",
        "//packages/chapter_08:openssl",
        "//packages/chapter_08:pkgconf",
        "//packages/chapter_08:zlib",
    ],
)

# Man pages skipped (need asciidoc); binaries, templates and the
# libcurl-based https remote helper are all installed by plain `make install`.
lfs_package(
    name = "git",
    srcs = ["@git_src//file"],
    build_cmd = "make -j$(nproc)",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --with-gitconfig=/etc/gitconfig \\
            --with-python=python3
    """,
    install_cmd = "make install",
    phase = "chroot",
    deps = [
        ":curl",
        "//packages/chapter_08:expat",
        "//packages/chapter_08:gettext",
        "//packages/chapter_08:openssl",
        "//packages/chapter_08:perl",
        "//packages/chapter_08:python",
        "//packages/chapter_08:zlib",
    ],
)

# Login + remote-access configuration: without a shadow hash root cannot log
# in at all (LFS leaves `root:x:` and the book's interactive `passwd` step
# never runs here). Root password: "lfs" — this is a local dev VM image.
lfs_script(
    name = "blfs_config",
    script = """
        HASH="$(openssl passwd -6 lfs)"
        sed -i "s|^root:[^:]*:|root:$HASH:|" /etc/shadow
        grep -q '^root:\\$6\\$' /etc/shadow

        # sshd: password root login for the dev VM
        echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
        systemctl enable sshd

        # DNS via systemd-resolved (networkd is already preset-enabled)
        systemctl enable systemd-resolved
        ln -sfv /run/systemd/resolve/resolv.conf /etc/resolv.conf
    """,
    deps = [
        ":openssh",
        "//packages/chapter_08:openssl",
        "//packages/chapter_08:systemd",
    ],
)

filegroup(
    name = "blfs",
    srcs = [
        ":blfs_config",
        ":ca_certificates",
        ":curl",
        ":git",
        ":openssh",
        ":sudo",
    ],
)
