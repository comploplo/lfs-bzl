#!/bin/bash
# Boot smoke test: boots sysroot/lfs-uefi.img in QEMU (read-only via -snapshot)
# and fails unless the systemd greeting and a login prompt appear.
#
# Runs unsandboxed (tags = ["local"]) so it can reach the sysroot image and
# the hvf accelerator. The image is not a tracked Bazel output; build it
# first with: bazel build //packages/chapter_11:bootable
set -u

if [ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]; then
    WORKSPACE_ROOT="$BUILD_WORKSPACE_DIRECTORY"
else
    # In runfiles this file is a symlink chain back into the source tree;
    # pwd -P resolves it, then walk up to the WORKSPACE file.
    WORKSPACE_ROOT=""
    CURRENT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    while [ "$CURRENT" != "/" ]; do
        if [ -f "$CURRENT/WORKSPACE" ] || [ -f "$CURRENT/MODULE.bazel" ]; then
            WORKSPACE_ROOT="$CURRENT"
            break
        fi
        CURRENT="$(dirname "$CURRENT")"
    done
fi

if [ -z "$WORKSPACE_ROOT" ]; then
    echo "FAIL: could not locate workspace root" >&2
    exit 1
fi

IMG="$WORKSPACE_ROOT/sysroot/lfs-uefi.img"
if [ ! -f "$IMG" ]; then
    echo "FAIL: $IMG not found. Build it first:" >&2
    echo "  bazel build //packages/chapter_11:bootable" >&2
    exit 1
fi

case "$(uname -m)" in
    arm64|aarch64) QEMU_NAME=qemu-system-aarch64; FW_NAME=edk2-aarch64-code.fd ;;
    x86_64)        QEMU_NAME=qemu-system-x86_64;  FW_NAME=edk2-x86_64-code.fd ;;
    *) echo "FAIL: unsupported host arch $(uname -m)" >&2; exit 1 ;;
esac

# Bazel's test PATH may not include Homebrew; resolve absolute paths.
QEMU="$(command -v "$QEMU_NAME" || true)"
[ -n "$QEMU" ] || QEMU="/opt/homebrew/bin/$QEMU_NAME"
FIRMWARE=""
for p in /opt/homebrew/share/qemu /usr/local/share/qemu /usr/share/qemu; do
    if [ -f "$p/$FW_NAME" ]; then FIRMWARE="$p/$FW_NAME"; break; fi
done
if [ ! -x "$QEMU" ] || [ -z "$FIRMWARE" ]; then
    echo "FAIL: qemu ($QEMU_NAME) or UEFI firmware ($FW_NAME) not installed" >&2
    exit 1
fi

case "$(uname -s)" in
    Darwin) ACCEL="-cpu host -accel hvf" ;;
    *)      ACCEL="-cpu max" ;;
esac

# SSH port forward: pick a free-ish high port so a manually-running VM on
# 2222 doesn't collide with the test.
SSH_PORT="${LFS_BOOT_TEST_SSH_PORT:-22322}"

export QEMU FIRMWARE IMG ACCEL SSH_PORT
exec expect <<'EXPECT_EOF'
set timeout 420
log_user 1

spawn sh -c "$env(QEMU) -M virt $env(ACCEL) -m 4G \
    -drive if=pflash,format=raw,readonly=on,file=$env(FIRMWARE) \
    -drive file=$env(IMG),format=raw,if=virtio,snapshot=on \
    -netdev user,id=n0,hostfwd=tcp::$env(SSH_PORT)-:22 \
    -device virtio-net-pci,netdev=n0 \
    -nographic"

# ANSI color codes sit between "Welcome to" and the distro name in the
# systemd greeting, so match only the contiguous name+version string.
expect {
    "Linux From Scratch 13.0-systemd" {}
    timeout { puts "\nFAIL: no systemd greeting within timeout"; exit 1 }
    eof     { puts "\nFAIL: qemu exited before greeting"; exit 1 }
}
expect {
    "lfs login:" {}
    timeout { puts "\nFAIL: no login prompt after greeting"; exit 1 }
    eof     { puts "\nFAIL: qemu exited before login prompt"; exit 1 }
}

# Log in as root and verify an interactive shell plus DHCP networking.
send "root\r"
expect {
    "Password:" { send "lfs\r" }
    "#"         {}
    timeout { puts "\nFAIL: no password prompt or shell after login"; exit 1 }
}
expect {
    "#" {}
    "Login incorrect" { puts "\nFAIL: root login rejected"; exit 1 }
    timeout { puts "\nFAIL: no root shell"; exit 1 }
}

# A bare "#" can match stray console output; prove we have a live shell.
# Braces keep Tcl from touching $((...)); the guest shell computes 42, so
# matching "42 LFS-BOOT-SHELL" can't be satisfied by the terminal echo.
send {echo $((6*7)) LFS-BOOT-SHELL}
send "\r"
expect {
    "42 LFS-BOOT-SHELL" {}
    timeout { puts "\nFAIL: root shell not interactive"; exit 1 }
}

send "ip -4 addr show; echo BOOTTEST-NET-$?\r"
expect {
    -re {inet 10\.0\.2\.\d+} {}
    timeout { puts "\nFAIL: no DHCP address on virtio-net"; exit 1 }
}

send "\x01x"
expect eof
puts "\nPASS: booted to root shell with networking"
exit 0
EXPECT_EOF
