"""
Chapter 9: System Configuration (Systemd)

Configures the system for booting, including:
- Systemd configuration (locale, clock, etc.)
- Network configuration (systemd-networkd)
- Shell startup files
"""

load("//tools:lfs_script.bzl", "lfs_script")

package(default_visibility = ["//visibility:public"])

# --------------------------------------------------------------------------- #
# Systemd Configuration
# --------------------------------------------------------------------------- #
lfs_script(
    name = "locale_config",
    script = """
        # Create /etc/locale.conf
        cat > /etc/locale.conf << "EOF"
LANG=en_US.UTF-8
EOF
    """,
    deps = ["//packages/chapter_08:toolchain"],
)

lfs_script(
    name = "inputrc_config",
    script = """
        # Create /etc/inputrc
        cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8-bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\\eOd": backward-word
"\\eOc": forward-word

# for linux console
"\\e[1~": beginning-of-line
"\\e[4~": end-of-line
"\\e[5~": beginning-of-history
"\\e[6~": end-of-history
"\\e[3~": delete-char
"\\e[2~": quoted-insert

# for xterm
"\\eOH": beginning-of-line
"\\eOF": end-of-line

# for Konsole
"\\e[H": beginning-of-line
"\\e[F": end-of-line

# End /etc/inputrc
EOF
    """,
    deps = ["//packages/chapter_08:toolchain"],
)

lfs_script(
    name = "shells_config",
    script = """
        # Create /etc/shells
        cat > /etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF
    """,
    deps = ["//packages/chapter_08:toolchain"],
)

lfs_script(
    name = "systemd_config",
    script = """
        # Create /etc/vconsole.conf
        cat > /etc/vconsole.conf << "EOF"
KEYMAP=us
FONT=Lat2-Terminus16
EOF

        # Create /etc/adjtime (PST)
        # Note: systemd expects the clock to be in UTC by default, but we set LOCAL
        # if dual-booting with Windows. For pure Linux, UTC is preferred.
        # However, user requested PST configuration which usually implies
        # setting the timezone, not necessarily the hardware clock to local.
        # We will set the timezone to America/Los_Angeles.

        ln -sfv /usr/share/zoneinfo/America/Los_Angeles /etc/localtime

        # Ensure /etc/adjtime exists and is set to UTC (standard for Linux)
        cat > /etc/adjtime << "EOF"
0.0 0 0.0
0
UTC
EOF
    """,
    deps = ["//packages/chapter_08:toolchain"],
)

# --------------------------------------------------------------------------- #
# Network Configuration
# --------------------------------------------------------------------------- #

lfs_script(
    name = "network_config",
    script = """
        # Create /etc/hostname
        echo "lfs" > /etc/hostname

        # Create /etc/hosts
        cat > /etc/hosts << "EOF"
# Begin /etc/hosts

127.0.0.1 localhost.localdomain localhost
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters

# End /etc/hosts
EOF

        # Create systemd-networkd configuration for DHCP
        mkdir -pv /etc/systemd/network
        cat > /etc/systemd/network/10-eth-dhcp.network << "EOF"
[Match]
Name=e*

[Network]
DHCP=ipv4

[DHCPv4]
UseDomains=true
EOF

        # Symlink resolv.conf to systemd-resolved stub
        ln -sfv /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    """,
    deps = [":systemd_config"],
)

# --------------------------------------------------------------------------- #
# Shell Startup Files
# --------------------------------------------------------------------------- #

lfs_script(
    name = "shell_config",
    script = """
        # Create /etc/profile
        cat > /etc/profile << "EOF"
# Begin /etc/profile

for i in $(locale); do
  unset ${i%=*}
done

if [[ "$TERM" = linux ]]; then
  export LANG=C.UTF-8
else
  source /etc/locale.conf

  for i in $(locale); do
    key=${i%=*}
    if [[ -v $key ]]; then
      export $key
    fi
  done
fi

# End /etc/profile
EOF
    """,
    deps = [":systemd_config"],
)

# --------------------------------------------------------------------------- #
# Fstab
# --------------------------------------------------------------------------- #

lfs_script(
    name = "fstab",
    script = """
        # Create /etc/fstab
        cat > /etc/fstab << "EOF"
# Begin /etc/fstab

# file system  mount-point  type     options             dump  fsck
#                                                              order

/dev/sda1      /            ext4     defaults            1     1
/dev/sda2      swap         swap     pri=1               0     0
proc           /proc        proc     nosuid,noexec,nodev 0     0
sysfs          /sys         sysfs    nosuid,noexec,nodev 0     0
devpts         /dev/pts     devpts   gid=5,mode=620      0     0
tmpfs          /run         tmpfs    defaults            0     0
devtmpfs       /dev         devtmpfs mode=0755,nosuid    0     0

# End /etc/fstab
EOF
    """,
    deps = [":systemd_config"],
)

# --------------------------------------------------------------------------- #
# Chapter 9 Aggregate
# --------------------------------------------------------------------------- #

filegroup(
    name = "chapter_09",
    srcs = [
        ":fstab",
        ":inputrc_config",
        ":locale_config",
        ":network_config",
        ":shell_config",
        ":shells_config",
        ":systemd_config",
    ],
)
