#!/usr/bin/env python3
"""
LFS Host System Requirements Check

This script verifies that the host system meets the requirements for building
Linux From Scratch (LFS), including software versions, kernel configuration,
and tool availability.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from typing import Optional, Tuple


def get_version(cmd: str) -> Optional[str]:
    """Run command and extract the first version number found in output."""
    try:
        # Capture both stdout and stderr
        result = subprocess.run(
            cmd, shell=True, text=True, capture_output=True, check=False
        )
        if result.returncode != 0 and "java" not in cmd:
             # Some commands like 'java -version' print to stderr but exit 0.
             # Others might exit non-zero but still print version?
             # For now, if it fails, we might still want to check output if it exists.
             pass

        output = result.stdout + result.stderr
        # Regex to find version numbers like 1.2.3, 5.4, 2.5.1a
        match = re.search(r'(\d+(?:\.\d+)+[a-z]?)', output)
        if match:
            return match.group(1)
    except Exception:
        pass
    return None


def version_tuple(v: str) -> Tuple[int, ...]:
    """Convert version string to tuple of integers for comparison."""
    # Remove any trailing letters (e.g., 2.5.1a -> 2.5.1) for simple comparison
    # Ideally we'd handle the letter, but for LFS requirements it's usually fine.
    # The C++ version handled suffixes, let's try to be robust.
    clean_v = re.sub(r'[a-z]+$', '', v)
    return tuple(map(int, clean_v.split('.')))


class TestSystemRequirements(unittest.TestCase):

    def check_version(self, name: str, cmd: str, min_version: str):
        """Helper to check a tool's version."""
        current = get_version(cmd)
        if current is None:
            self.fail(f"{name}: Command '{cmd}' failed or version not found.")

        # Simple tuple comparison
        if version_tuple(current) < version_tuple(min_version):
            self.fail(f"{name}: Version {current} is too old (required >= {min_version})")

        print(f"OK:    {name} {current} >= {min_version}")

    def test_coreutils_sort(self):
        self.check_version("Coreutils (sort)", "sort --version", "8.1")

    def test_bash(self):
        self.check_version("Bash", "bash --version", "3.2")
        # Check if sh is bash
        try:
            res = subprocess.run(["sh", "--version"], capture_output=True, text=True)
            if "bash" not in res.stdout.lower():
                 print("WARNING: /bin/sh does not appear to be bash. This might cause issues.")
            else:
                 print("OK:    sh is Bash")
        except Exception:
            self.fail("Could not check /bin/sh version")

    def test_binutils_ld(self):
        self.check_version("Binutils (ld)", "ld --version", "2.13.1")

    def test_bison(self):
        self.check_version("Bison", "bison --version", "2.7")
        # Check yacc alias
        try:
            res = subprocess.run(["yacc", "--version"], capture_output=True, text=True)
            if "bison" not in res.stdout.lower() and "bison" not in res.stderr.lower():
                print("WARNING: yacc does not appear to be Bison.")
            else:
                print("OK:    yacc is Bison")
        except FileNotFoundError:
             print("WARNING: yacc command not found.")

    def test_diffutils(self):
        self.check_version("Diffutils", "diff --version", "2.8.1")

    def test_findutils(self):
        self.check_version("Findutils", "find --version", "4.2.31")

    def test_gawk(self):
        self.check_version("Gawk", "gawk --version", "4.0.1")
        # Check awk alias
        try:
            res = subprocess.run(["awk", "--version"], capture_output=True, text=True)
            if "gnu" not in res.stdout.lower():
                print("WARNING: awk does not appear to be GNU awk.")
            else:
                print("OK:    awk is GNU awk")
        except Exception:
            pass

    def test_gcc(self):
        self.check_version("GCC", "gcc --version", "5.4")
        self.check_version("G++", "g++ --version", "5.4")

    def test_grep(self):
        self.check_version("Grep", "grep --version", "2.5.1")

    def test_gzip(self):
        self.check_version("Gzip", "gzip --version", "1.3.12")

    def test_m4(self):
        self.check_version("M4", "m4 --version", "1.4.10")

    def test_make(self):
        self.check_version("Make", "make --version", "4.0")

    def test_patch(self):
        self.check_version("Patch", "patch --version", "2.5.4")

    def test_perl(self):
        self.check_version("Perl", "perl -V:version", "5.8.8")

    def test_python(self):
        self.check_version("Python", "python3 --version", "3.4")

    def test_sed(self):
        self.check_version("Sed", "sed --version", "4.1.5")

    def test_tar(self):
        self.check_version("Tar", "tar --version", "1.22")

    def test_texinfo(self):
        self.check_version("Texinfo", "texi2any --version", "5.0")

    def test_xz(self):
        self.check_version("Xz", "xz --version", "5.0.0")

    def test_podman(self):
        # New check for Podman
        # We don't have a strict minimum version in the prompt, but README says 3.0+
        self.check_version("Podman", "podman --version", "3.0.0")

    def test_kernel(self):
        # Check kernel version
        uname = os.uname()
        release = uname.release
        print(f"Kernel release: {release}")

        # Extract version
        match = re.match(r'(\d+\.\d+)', release)
        if not match:
            self.fail(f"Could not parse kernel version from {release}")

        ver = match.group(1)
        if version_tuple(ver) < version_tuple("5.4"):
            self.fail(f"Kernel {ver} is too old (required >= 5.4)")
        print(f"OK:    Linux Kernel {ver} >= 5.4")

        # Check PTY support
        if not os.path.exists("/dev/ptmx"):
             self.fail("/dev/ptmx does not exist. Kernel might lack PTY support.")

        # Check for devpts mount
        with open("/proc/mounts", "r") as f:
            mounts = f.read()
            if "devpts" not in mounts:
                self.fail("devpts not mounted. Kernel might lack PTY support.")
        print("OK:    Linux Kernel supports UNIX 98 PTY")

    def test_compiler_works(self):
        """Check if we can compile a simple C program."""
        with tempfile.TemporaryDirectory() as tmpdir:
            src = os.path.join(tmpdir, "test.c")
            exe = os.path.join(tmpdir, "test")
            with open(src, "w") as f:
                f.write("int main() { return 0; }\n")

            try:
                subprocess.run(
                    ["gcc", "-o", exe, src],
                    check=True,
                    capture_output=True
                )
                print("OK:    GCC compilation works")
            except subprocess.CalledProcessError as e:
                self.fail(f"GCC compilation failed:\n{e.stderr.decode()}")
            except FileNotFoundError:
                self.fail("GCC command not found")

    def test_nproc(self):
        try:
            res = subprocess.run(["nproc"], capture_output=True, text=True, check=True)
            count = res.stdout.strip()
            if not count.isdigit() or int(count) < 1:
                self.fail(f"nproc returned invalid value: {count}")
            print(f"OK:    nproc reports {count} cores")
        except Exception as e:
            self.fail(f"nproc check failed: {e}")


if __name__ == '__main__':
    unittest.main(verbosity=2)
