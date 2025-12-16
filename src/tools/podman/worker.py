#!/usr/bin/env python3
"""
Bazel JSON Worker for LFS Chroot Builds

This worker implements the Bazel JSON worker protocol to execute LFS package
builds inside a chroot environment within a rootless Podman container.

Protocol: https://bazel.build/remote/persistent
"""

import argparse
import atexit
import json
import os
import shutil
import signal
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

# Build timeout in seconds (2 hours default)
DEFAULT_BUILD_TIMEOUT = 7200


class BazelWorker:
    """
    Bazel JSON Worker implementation.

    Manages the lifecycle of a persistent worker process, including:
    - VFS setup (mounting /dev, /proc, etc.)
    - Request processing loop
    - Build execution in chroot
    - Cleanup on shutdown
    """

    # Mount points required for the chroot environment
    MOUNT_POINTS = [
        '/lfs/dev',
        '/lfs/proc',
        '/lfs/sys',
        '/lfs/run',
        '/lfs/tmp',
        '/lfs/execroot',
    ]

    # Critical directories to normalize ownership for
    NORMALIZE_DIRS = [
        '/lfs/usr',
        '/lfs/etc',
        '/lfs/var',
        '/lfs/lib',
        '/lfs/lib64',
        '/lfs/bin',
        '/lfs/sbin',
    ]

    def __init__(self, external_dir: Optional[str] = None):
        """
        Initialize the worker.

        Args:
            external_dir: Absolute path to Bazel external directory to mount.
        """
        self.external_dir = external_dir
        self._mounts: List[str] = []
        self._cleanup_done = False

        # Register signal handlers
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)
        atexit.register(self.cleanup_mounts)

    def _signal_handler(self, signum: int, frame: Any) -> None:
        """Handle SIGTERM and SIGINT for graceful shutdown."""
        sig_name = signal.Signals(signum).name
        sys.stderr.write(f"[WORKER] Received {sig_name}, shutting down gracefully...\n")
        sys.stderr.flush()
        self.cleanup_mounts()
        sys.exit(128 + signum)

    def cleanup_mounts(self) -> None:
        """Unmount all VFS mounts in reverse order for graceful shutdown."""
        if self._cleanup_done:
            return
        self._cleanup_done = True

        if not self._mounts:
            return

        sys.stderr.write("[WORKER] Cleaning up mounts...\n")
        sys.stderr.flush()

        # Unmount in reverse order (LIFO) to handle nested mounts
        for mount_point in reversed(self._mounts):
            try:
                # Use lazy unmount (-l) to handle busy filesystems
                subprocess.run(
                    ['umount', '-l', mount_point],
                    check=False,
                    capture_output=True
                )
                sys.stderr.write(f"[WORKER] Unmounted {mount_point}\n")
            except Exception as e:
                sys.stderr.write(f"[WORKER] Warning: Failed to unmount {mount_point}: {e}\n")
            sys.stderr.flush()

    def _mount_filesystem(self, source: str, target: str, options: Optional[List[str]] = None) -> None:
        """
        Bind mount a filesystem and track it for cleanup.

        Args:
            source: Source path.
            target: Target path (inside chroot).
            options: Additional mount options (e.g., ['--make-rprivate']).
        """
        cmd = ['mount', '--rbind', source, target]
        if options:
            cmd.extend(options)

        try:
            subprocess.run(cmd, check=True)
            self._mounts.append(target)
            # sys.stderr.write(f"[WORKER] Mounted {source} -> {target}\n")
        except subprocess.CalledProcessError as e:
            sys.stderr.write(f"[WORKER] Error mounting {source} -> {target}: {e}\n")
            raise

    def prepare_chroot(self) -> None:
        """
        One-time VFS setup on worker startup.

        Mounts virtual filesystems into /lfs for chroot environment.
        """
        sys.stderr.write("[WORKER] Preparing chroot environment...\n")
        sys.stderr.flush()

        # Create mount points
        for dir_path in self.MOUNT_POINTS:
            os.makedirs(dir_path, exist_ok=True)

        if self.external_dir:
            external_mount_point = f'/lfs{self.external_dir}'
            os.makedirs(external_mount_point, exist_ok=True)
            sys.stderr.write(f"[WORKER] Will mount {self.external_dir} -> {external_mount_point}\n")

        try:
            # Bind mount virtual filesystems
            self._mount_filesystem('/dev', '/lfs/dev')
            self._mount_filesystem('/proc', '/lfs/proc')
            self._mount_filesystem('/sys', '/lfs/sys')
            self._mount_filesystem('/run', '/lfs/run')

            # Bind mount execroot
            self._mount_filesystem('/execroot', '/lfs/execroot')

            # Bind mount external directory
            if self.external_dir:
                external_mount_point = f'/lfs{self.external_dir}'
                self._mount_filesystem(self.external_dir, external_mount_point)
                sys.stderr.write(f"[WORKER] Mounted {self.external_dir} -> {external_mount_point}\n")

            # Isolate mount propagation
            subprocess.run(['mount', '--make-rprivate', '/lfs'], check=True)

            sys.stderr.write("[WORKER] Chroot environment ready\n")

            self._create_tester_user()

        except subprocess.CalledProcessError as e:
            sys.stderr.write(f"[WORKER] Error preparing chroot: {e}\n")
            sys.stderr.flush()
            raise

    def _create_tester_user(self) -> None:
        """Create tester user for test suites."""
        sys.stderr.write("[WORKER] Creating tester user for test suites\n")
        sys.stderr.flush()
        try:
            subprocess.run(
                ['chroot', '/lfs', '/usr/bin/useradd', '-m', '-d', '/home/tester', 'tester'],
                check=False  # Don't fail if user exists
            )
        except subprocess.CalledProcessError as e:
            sys.stderr.write(f"[WORKER] Warning: Could not create tester user: {e}\n")

    def parse_args(self, arguments: List[str]) -> argparse.Namespace:
        """Parse worker arguments from the request."""
        parser = argparse.ArgumentParser()
        parser.add_argument('--script', required=True, help='Build script path')
        parser.add_argument('--done', required=True, help='Success marker path')
        parser.add_argument('--log', required=True, help='Log file path')
        return parser.parse_args(arguments)

    def _stage_script(self, script_path: str) -> None:
        """Stage the build script into the chroot."""
        # Script paths are relative to execroot, which is mounted at /execroot
        full_script_path = script_path if script_path.startswith('/') else f'/execroot/{script_path}'
        sys.stderr.write(f"[WORKER] Staging script: {full_script_path} -> /lfs/tmp/build.sh\n")

        shutil.copy(full_script_path, '/lfs/tmp/build.sh')
        os.chmod('/lfs/tmp/build.sh', 0o755)

    def _normalize_ownership(self) -> None:
        """
        Normalize file ownership in sysroot to prevent permission conflicts.

        This ensures files created during this build can be overwritten in future builds
        in rootless Podman environments.
        """
        sys.stderr.write(f"[WORKER] Normalizing file ownership in /lfs...\n")
        try:
            for directory in self.NORMALIZE_DIRS:
                if os.path.exists(directory):
                    subprocess.run(['chown', '-R', 'root:root', directory], check=False)
        except Exception as e:
            sys.stderr.write(f"[WORKER] Warning: Failed to normalize ownership: {e}\n")

    def process_request(self, req: Dict[str, Any]) -> Dict[str, Any]:
        """
        Handle a single build request.

        Args:
            req: JSON request object.

        Returns:
            JSON response object.
        """
        request_id = req.get('requestId', 0)

        try:
            args = self.parse_args(req.get('arguments', []))

            sys.stderr.write(f"[WORKER] Processing request {request_id}\n")
            sys.stderr.flush()

            self._stage_script(args.script)

            # Execute in chroot with clean environment
            env = {
                'HOME': '/root',
                'LC_ALL': 'C',
                'TERM': os.environ.get('TERM', 'linux'),
                'LFS': '/',
                'PATH': '/usr/bin:/usr/sbin:/bin:/sbin',
                'MAKEFLAGS': '-j$(nproc)',
            }

            # Use /usr/bin/bash (installed by Chapter 6 gcc_pass2)
            cmd = ['chroot', '/lfs', '/usr/bin/env', '-i'] + \
                  [f'{k}={v}' for k, v in env.items()] + \
                  ['/usr/bin/bash', '-lc', 'source /tmp/build.sh']

            timeout_secs = req.get('timeout', DEFAULT_BUILD_TIMEOUT)
            sys.stderr.write(f"[WORKER] Executing in chroot (timeout: {timeout_secs}s)...\n")
            sys.stderr.flush()

            try:
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=timeout_secs
                )
            except subprocess.TimeoutExpired:
                sys.stderr.write(f"[WORKER] Build timed out after {timeout_secs} seconds\n")

                log_path = args.log if args.log.startswith('/') else f'/execroot/{args.log}'
                with open(log_path, 'w') as f:
                    f.write(f"BUILD TIMEOUT: Exceeded {timeout_secs} seconds\n")

                return {'requestId': request_id, 'exitCode': 124, 'error': 'timeout'}

            # Write outputs
            log_path = args.log if args.log.startswith('/') else f'/execroot/{args.log}'
            done_path = args.done if args.done.startswith('/') else f'/execroot/{args.done}'

            sys.stderr.write(f"[WORKER] Writing log to {log_path}\n")

            with open(log_path, 'w') as f:
                f.write(result.stdout)
                f.write(result.stderr)

            if result.returncode == 0:
                self._normalize_ownership()
                sys.stderr.write(f"[WORKER] Build succeeded, creating marker {done_path}\n")
                Path(done_path).touch()
            else:
                sys.stderr.write(f"[WORKER] Build failed with exit code {result.returncode}\n")

            sys.stderr.flush()
            return {'requestId': request_id, 'exitCode': result.returncode}

        except Exception as e:
            sys.stderr.write(f"[WORKER] Error processing request: {e}\n")
            sys.stderr.flush()
            return {'requestId': request_id, 'exitCode': 1, 'output': str(e)}

    def run(self) -> None:
        """Main worker loop."""
        try:
            self.prepare_chroot()

            sys.stderr.write("[WORKER] Ready\n")
            sys.stderr.flush()

            for line in sys.stdin:
                line = line.strip()
                if not line:
                    continue

                # sys.stderr.write(f"[WORKER] Received input: {line[:200]}\n")

                try:
                    req = json.loads(line)
                    resp = self.process_request(req)

                    sys.stdout.write(json.dumps(resp) + '\n')
                    sys.stdout.flush()

                except json.JSONDecodeError as e:
                    sys.stderr.write(f"[WORKER] Invalid JSON: {e}\n")
                    sys.stderr.flush()
                except Exception as e:
                    sys.stderr.write(f"[WORKER] Error in main loop: {e}\n")
                    sys.stderr.flush()

        except KeyboardInterrupt:
            sys.stderr.write("[WORKER] Interrupted\n")
            sys.stderr.flush()
        except Exception as e:
            sys.stderr.write(f"[WORKER] Fatal error: {e}\n")
            sys.stderr.flush()
            sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description='Bazel JSON worker for LFS chroot builds')
    parser.add_argument('--external-dir', help='Path to Bazel external directory')
    args = parser.parse_args()

    worker = BazelWorker(args.external_dir)
    worker.run()


if __name__ == '__main__':
    main()
