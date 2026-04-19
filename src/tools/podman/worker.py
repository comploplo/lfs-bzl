#!/usr/bin/env python3
"""
Bazel JSON Worker for LFS Builds

This worker implements the Bazel JSON worker protocol to execute LFS package
builds inside a rootless Podman container. It supports two execution modes:

- container: Direct execution inside the container (chapters 5-6)
- chroot: Execution inside a chroot at /lfs (chapters 7-11)

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

DEFAULT_BUILD_TIMEOUT = 7200


class BazelWorker:
    """
    Bazel JSON Worker implementation.

    Manages the lifecycle of a persistent worker process, including:
    - Optional VFS setup (mounting /dev, /proc, etc.) for chroot mode
    - Request processing loop
    - Build execution in container or chroot mode
    - Cleanup on shutdown
    """

    MOUNT_POINTS = [
        '/lfs/dev',
        '/lfs/proc',
        '/lfs/sys',
        '/lfs/run',
        '/lfs/tmp',
        '/lfs/execroot',
    ]

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
        self.external_dir = external_dir
        self._mounts: List[str] = []
        self._cleanup_done = False
        self._chroot_prepared = False

        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)
        atexit.register(self.cleanup_mounts)

    def _signal_handler(self, signum: int, frame: Any) -> None:
        sig_name = signal.Signals(signum).name
        sys.stderr.write(f"[WORKER] Received {sig_name}, shutting down gracefully...\n")
        sys.stderr.flush()
        self.cleanup_mounts()
        sys.exit(128 + signum)

    def cleanup_mounts(self) -> None:
        if self._cleanup_done:
            return
        self._cleanup_done = True

        if not self._mounts:
            return

        sys.stderr.write("[WORKER] Cleaning up mounts...\n")
        sys.stderr.flush()

        for mount_point in reversed(self._mounts):
            try:
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
        cmd = ['mount', '--rbind', source, target]
        if options:
            cmd.extend(options)

        try:
            subprocess.run(cmd, check=True)
            self._mounts.append(target)
        except subprocess.CalledProcessError as e:
            sys.stderr.write(f"[WORKER] Error mounting {source} -> {target}: {e}\n")
            raise

    def prepare_chroot(self) -> None:
        sys.stderr.write("[WORKER] Preparing chroot environment...\n")
        sys.stderr.flush()

        for dir_path in self.MOUNT_POINTS:
            os.makedirs(dir_path, exist_ok=True)

        if self.external_dir:
            external_mount_point = f'/lfs{self.external_dir}'
            os.makedirs(external_mount_point, exist_ok=True)
            sys.stderr.write(f"[WORKER] Will mount {self.external_dir} -> {external_mount_point}\n")

        try:
            self._mount_filesystem('/dev', '/lfs/dev')
            self._mount_filesystem('/proc', '/lfs/proc')
            self._mount_filesystem('/sys', '/lfs/sys')
            self._mount_filesystem('/run', '/lfs/run')
            self._mount_filesystem('/execroot', '/lfs/execroot')

            if self.external_dir:
                external_mount_point = f'/lfs{self.external_dir}'
                self._mount_filesystem(self.external_dir, external_mount_point)
                sys.stderr.write(f"[WORKER] Mounted {self.external_dir} -> {external_mount_point}\n")

            subprocess.run(['mount', '--make-rprivate', '/lfs'], check=True)

            sys.stderr.write("[WORKER] Chroot environment ready\n")

            self._create_tester_user()

        except subprocess.CalledProcessError as e:
            sys.stderr.write(f"[WORKER] Error preparing chroot: {e}\n")
            sys.stderr.flush()
            raise

    def _create_tester_user(self) -> None:
        sys.stderr.write("[WORKER] Creating tester user for test suites\n")
        sys.stderr.flush()
        try:
            subprocess.run(
                ['chroot', '/lfs', '/usr/bin/useradd', '-m', '-d', '/home/tester', 'tester'],
                check=False
            )
        except subprocess.CalledProcessError as e:
            sys.stderr.write(f"[WORKER] Warning: Could not create tester user: {e}\n")

    def parse_args(self, arguments: List[str]) -> argparse.Namespace:
        parser = argparse.ArgumentParser()
        parser.add_argument('--mode', required=True, choices=['container', 'chroot'])
        parser.add_argument('--script', required=True)
        parser.add_argument('--done', required=True)
        parser.add_argument('--log', required=True)
        return parser.parse_args(arguments)

    def _resolve_path(self, path: str) -> str:
        if path.startswith('/'):
            return path
        return f'/execroot/{path}'

    def _run_build(self, cmd: List[str], args: argparse.Namespace,
                   request_id: int, req: Dict[str, Any]) -> Dict[str, Any]:
        timeout_secs = req.get('timeout', DEFAULT_BUILD_TIMEOUT)

        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                start_new_session=True,
            )
            stdout, stderr = proc.communicate(timeout=timeout_secs)
            result = subprocess.CompletedProcess(cmd, proc.returncode, stdout, stderr)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
            except (ProcessLookupError, OSError):
                pass
            proc.kill()
            proc.wait()
            sys.stderr.write(f"[WORKER] Build timed out after {timeout_secs} seconds\n")

            log_path = self._resolve_path(args.log)
            with open(log_path, 'w') as f:
                f.write(f"BUILD TIMEOUT: Exceeded {timeout_secs} seconds\n")

            return {'requestId': request_id, 'exitCode': 124, 'error': 'timeout'}

        log_path = self._resolve_path(args.log)
        done_path = self._resolve_path(args.done)

        sys.stderr.write(f"[WORKER] Writing log to {log_path}\n")

        with open(log_path, 'w') as f:
            f.write(result.stdout)
            f.write(result.stderr)

        if result.returncode == 0:
            sys.stderr.write(f"[WORKER] Build succeeded, creating marker {done_path}\n")
            Path(done_path).touch()
        else:
            sys.stderr.write(f"[WORKER] Build failed with exit code {result.returncode}\n")

        sys.stderr.flush()
        return {'requestId': request_id, 'exitCode': result.returncode}

    def _execute_container(self, args: argparse.Namespace,
                           request_id: int, req: Dict[str, Any]) -> Dict[str, Any]:
        script_path = self._resolve_path(args.script)
        sys.stderr.write(f"[WORKER] Executing in container mode: {script_path}\n")
        sys.stderr.flush()

        env = {
            'HOME': '/root',
            'LC_ALL': 'POSIX',
            'TERM': os.environ.get('TERM', 'linux'),
            'LFS': '/lfs',
            'LFS_TGT': 'x86_64-lfs-linux-gnu',
            'PATH': '/lfs/tools/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
            'MAKEFLAGS': f'-j{os.cpu_count()}',
        }

        cmd = ['/usr/bin/env', '-i'] + \
              [f'{k}={v}' for k, v in env.items()] + \
              ['/bin/bash', '-lc', f'source {script_path}']

        return self._run_build(cmd, args, request_id, req)

    def _execute_chroot(self, args: argparse.Namespace,
                        request_id: int, req: Dict[str, Any]) -> Dict[str, Any]:
        full_script_path = self._resolve_path(args.script)
        sys.stderr.write(f"[WORKER] Staging script: {full_script_path} -> /lfs/tmp/build.sh\n")

        shutil.copy(full_script_path, '/lfs/tmp/build.sh')
        os.chmod('/lfs/tmp/build.sh', 0o755)

        env = {
            'HOME': '/root',
            'LC_ALL': 'C',
            'TERM': os.environ.get('TERM', 'linux'),
            'LFS': '/',
            'PATH': '/usr/bin:/usr/sbin:/bin:/sbin',
            'MAKEFLAGS': f'-j{os.cpu_count()}',
        }

        cmd = ['chroot', '/lfs', '/usr/bin/env', '-i'] + \
              [f'{k}={v}' for k, v in env.items()] + \
              ['/usr/bin/bash', '-lc', 'source /tmp/build.sh']

        sys.stderr.write(f"[WORKER] Executing in chroot (timeout: {req.get('timeout', DEFAULT_BUILD_TIMEOUT)}s)...\n")
        sys.stderr.flush()

        result = self._run_build(cmd, args, request_id, req)

        if result.get('exitCode') == 0:
            self._normalize_ownership()

        return result

    def _normalize_ownership(self) -> None:
        sys.stderr.write("[WORKER] Normalizing file ownership in /lfs...\n")
        try:
            for directory in self.NORMALIZE_DIRS:
                if os.path.exists(directory):
                    subprocess.run(['chown', '-R', 'root:root', directory], check=False)
        except Exception as e:
            sys.stderr.write(f"[WORKER] Warning: Failed to normalize ownership: {e}\n")

    def process_request(self, req: Dict[str, Any]) -> Dict[str, Any]:
        request_id = req.get('requestId', 0)

        try:
            args = self.parse_args(req.get('arguments', []))

            sys.stderr.write(f"[WORKER] Processing request {request_id} (mode={args.mode})\n")
            sys.stderr.flush()

            if args.mode == 'chroot':
                if not self._chroot_prepared:
                    self.prepare_chroot()
                    self._chroot_prepared = True
                return self._execute_chroot(args, request_id, req)
            else:
                return self._execute_container(args, request_id, req)

        except Exception as e:
            sys.stderr.write(f"[WORKER] Error processing request: {e}\n")
            sys.stderr.flush()
            return {'requestId': request_id, 'exitCode': 1, 'output': str(e)}

    def run(self) -> None:
        try:
            sys.stderr.write("[WORKER] Ready\n")
            sys.stderr.flush()

            for line in sys.stdin:
                line = line.strip()
                if not line:
                    continue

                try:
                    req = json.loads(line)
                    resp = self.process_request(req)

                    sys.stdout.write(json.dumps(resp) + '\n')
                    sys.stdout.flush()

                except json.JSONDecodeError as e:
                    sys.stderr.write(f"[WORKER] Invalid JSON: {e}\n")
                    sys.stderr.flush()
                    sys.stdout.write(json.dumps({
                        'exitCode': 1,
                        'output': f'Invalid JSON in work request: {e}'
                    }) + '\n')
                    sys.stdout.flush()
                except Exception as e:
                    sys.stderr.write(f"[WORKER] Error in main loop: {e}\n")
                    sys.stderr.flush()
                    sys.stdout.write(json.dumps({
                        'exitCode': 1,
                        'output': f'Worker error: {e}'
                    }) + '\n')
                    sys.stdout.flush()

        except KeyboardInterrupt:
            sys.stderr.write("[WORKER] Interrupted\n")
            sys.stderr.flush()
        except Exception as e:
            sys.stderr.write(f"[WORKER] Fatal error: {e}\n")
            sys.stderr.flush()
            sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description='Bazel JSON worker for LFS builds')
    parser.add_argument('--external-dir', help='Path to Bazel external directory')
    args = parser.parse_args()

    worker = BazelWorker(args.external_dir)
    worker.run()


if __name__ == '__main__':
    main()
