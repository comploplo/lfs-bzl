#!/usr/bin/env python3
"""
Host prerequisite check: verifies Podman is available.

All LFS builds run inside a Podman container, so this is the only
host-side requirement. Tool version checks run inside the container
via the :version_check target.
"""

import re
import subprocess
import unittest


class TestPodmanAvailable(unittest.TestCase):

    def test_podman_installed(self):
        result = subprocess.run(
            ['podman', '--version'],
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
            ['podman', 'image', 'exists', 'lfs-builder:bookworm'],
            capture_output=True, text=True, check=False,
        )
        if result.returncode != 0:
            self.skipTest(
                "Container image 'lfs-builder:bookworm' not built yet. "
                "Run: bazel run //tools/podman:container_image"
            )
        print("OK:   lfs-builder:bookworm image exists")


if __name__ == '__main__':
    unittest.main(verbosity=2)
