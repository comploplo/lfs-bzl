#!/usr/bin/env python3
"""
Host prerequisite check: verifies Podman is available.

All LFS builds run inside a Podman container, so this is the only
host-side requirement. Tool version checks run inside the container
via the :version_check target.
"""

import re
import shutil
import subprocess
import unittest

# The bazel test sandbox strips PATH down past /opt/homebrew/bin (where
# podman lives on Apple Silicon); resolve an absolute path with fallbacks.
PODMAN = (
    shutil.which('podman')
    or next((p for p in ('/opt/homebrew/bin/podman', '/usr/local/bin/podman', '/usr/bin/podman')
             if shutil.which(p)), None)
)


class TestPodmanAvailable(unittest.TestCase):

    def setUp(self):
        if PODMAN is None:
            self.fail("podman not found on PATH or in standard install locations")

    def test_podman_installed(self):
        result = subprocess.run(
            [PODMAN, '--version'],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 0, "podman not found")

        match = re.search(r'(\d+\.\d+(\.\d+)?)', result.stdout)
        self.assertIsNotNone(match, f"Could not parse podman version from: {result.stdout}")

        version = match.group(1)
        parts = tuple(int(x) for x in version.split('.'))
        self.assertGreaterEqual(parts, (3, 0), f"Podman {version} too old (need >= 3.0)")
        print(f"OK:   Podman {version} >= 3.0")

    def test_container_image_exists(self):
        result = subprocess.run(
            [PODMAN, 'image', 'exists', 'lfs-builder:trixie'],
            capture_output=True, text=True, check=False,
        )
        if result.returncode != 0:
            self.skipTest(
                "Container image 'lfs-builder:trixie' not built yet. "
                "Run: bazel run //tools/podman:container_image"
            )
        print("OK:   lfs-builder:trixie image exists")


if __name__ == '__main__':
    unittest.main(verbosity=2)
