#!/usr/bin/env python3
"""
Bazel JSON Worker for LFS Chroot Builds

This worker implements the Bazel JSON worker protocol to execute LFS package
builds inside a chroot environment within a rootless Podman container.

Protocol: https://bazel.build/remote/persistent
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def prepare_chroot(external_dir):
    """
    One-time VFS setup on worker startup.

    Mounts virtual filesystems into /lfs for chroot environment:
    - /dev: Device files
    - /proc: Process information
    - /sys: Kernel interface
    - /run: Runtime data
    - /execroot: Bazel workspace
    - external_dir: Source tarballs (mounted at absolute path to match symlinks)

    Args:
        external_dir: Absolute path to Bazel external directory
    """
    sys.stderr.write("[WORKER] Preparing chroot environment...\n")
    sys.stderr.flush()

    # Create mount points inside /lfs
    mount_points = ['/lfs/dev', '/lfs/proc', '/lfs/sys', '/lfs/run', '/lfs/tmp', '/lfs/execroot']

    # Mount external dir at same absolute path so symlinks resolve
    if external_dir:
        external_mount_point = f'/lfs{external_dir}'
        mount_points.append(external_mount_point)
        sys.stderr.write(f"[WORKER] Will mount {external_dir} -> {external_mount_point}\n")
        sys.stderr.flush()

    for dir_path in mount_points:
        os.makedirs(dir_path, exist_ok=True)

    try:
        # Bind mount virtual filesystems
        subprocess.run(['mount', '--rbind', '/dev', '/lfs/dev'], check=True)
        subprocess.run(['mount', '--rbind', '/proc', '/lfs/proc'], check=True)
        subprocess.run(['mount', '--rbind', '/sys', '/lfs/sys'], check=True)
        subprocess.run(['mount', '--rbind', '/run', '/lfs/run'], check=True)

        # Bind mount execroot so build scripts can access workspace
        subprocess.run(['mount', '--rbind', '/execroot', '/lfs/execroot'], check=True)

        # Bind mount external directory at its absolute path so symlinks work
        if external_dir:
            external_mount_point = f'/lfs{external_dir}'
            subprocess.run(['mount', '--rbind', external_dir, external_mount_point], check=True)
            sys.stderr.write(f"[WORKER] Mounted {external_dir} -> {external_mount_point}\n")
            sys.stderr.flush()

        # Isolate mount propagation
        subprocess.run(['mount', '--make-rprivate', '/lfs'], check=True)

        sys.stderr.write("[WORKER] Chroot environment ready\n")
        sys.stderr.flush()

        # Create tester user for test suites
        sys.stderr.write("[WORKER] Creating tester user for test suites\n")
        sys.stderr.flush()
        try:
            subprocess.run(
                ['chroot', '/lfs', '/usr/bin/useradd', '-m', '-d', '/home/tester', 'tester'],
                check=False  # Don't fail if user exists
            )
        except subprocess.CalledProcessError as e:
            sys.stderr.write(f"[WORKER] Warning: Could not create tester user: {e}\n")
            sys.stderr.flush()
    except subprocess.CalledProcessError as e:
        sys.stderr.write(f"[WORKER] Error preparing chroot: {e}\n")
        sys.stderr.flush()
        raise


def parse_args(arguments):
    """
    Parse worker arguments.

    Expected arguments:
    - --script: Path to build script in execroot
    - --done: Path to output marker file
    - --log: Path to output log file
    """
    parser = argparse.ArgumentParser()
    parser.add_argument('--script', required=True, help='Build script path')
    parser.add_argument('--done', required=True, help='Success marker path')
    parser.add_argument('--log', required=True, help='Log file path')

    return parser.parse_args(arguments)


def process_request(req):
    """
    Handle a single build request.

    Args:
        req: JSON request object with optional 'requestId' and 'arguments'

    Returns:
        JSON response object with optional 'requestId' and 'exitCode'
    """
    request_id = req.get('requestId', 0)
    args = parse_args(req['arguments'])

    sys.stderr.write(f"[WORKER] Processing request {request_id}\n")
    sys.stderr.flush()

    try:
        # Stage script: /execroot/path -> /lfs/tmp/build.sh
        # Script paths are relative to execroot, which is mounted at /execroot
        script_path = args.script if args.script.startswith('/') else f'/execroot/{args.script}'
        sys.stderr.write(f"[WORKER] Staging script: {script_path} -> /lfs/tmp/build.sh\n")
        sys.stderr.flush()

        shutil.copy(script_path, '/lfs/tmp/build.sh')
        os.chmod('/lfs/tmp/build.sh', 0o755)

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
        # /bin/bash won't exist until Chapter 7 creates the symlink
        cmd = ['chroot', '/lfs', '/usr/bin/env', '-i'] + \
              [f'{k}={v}' for k, v in env.items()] + \
              ['/usr/bin/bash', '-lc', 'source /tmp/build.sh']

        sys.stderr.write(f"[WORKER] Executing in chroot...\n")
        sys.stderr.flush()

        result = subprocess.run(cmd, capture_output=True, text=True)

        # Write outputs (paths relative to execroot)
        log_path = args.log if args.log.startswith('/') else f'/execroot/{args.log}'
        done_path = args.done if args.done.startswith('/') else f'/execroot/{args.done}'

        sys.stderr.write(f"[WORKER] Writing log to {log_path}\n")
        sys.stderr.flush()

        with open(log_path, 'w') as f:
            f.write(result.stdout)
            f.write(result.stderr)

        # Create success marker if build succeeded
        if result.returncode == 0:
            # Normalize file ownership in sysroot to prevent permission conflicts
            # in rootless Podman environments. This ensures files created during
            # this build can be overwritten in future builds.
            sys.stderr.write(f"[WORKER] Normalizing file ownership in /lfs...\n")
            sys.stderr.flush()
            try:
                # Only normalize critical directories to avoid changing mount points
                for directory in ['/lfs/usr', '/lfs/etc', '/lfs/var', '/lfs/lib', '/lfs/lib64', '/lfs/bin', '/lfs/sbin']:
                    if os.path.exists(directory):
                        subprocess.run(['chown', '-R', 'root:root', directory], check=False)
            except Exception as e:
                sys.stderr.write(f"[WORKER] Warning: Failed to normalize ownership: {e}\n")
                sys.stderr.flush()

            sys.stderr.write(f"[WORKER] Build succeeded, creating marker {done_path}\n")
            sys.stderr.flush()
            Path(done_path).touch()
        else:
            sys.stderr.write(f"[WORKER] Build failed with exit code {result.returncode}\n")
            sys.stderr.flush()

        return {'requestId': request_id, 'exitCode': result.returncode}

    except Exception as e:
        sys.stderr.write(f"[WORKER] Error processing request: {e}\n")
        sys.stderr.flush()
        return {'requestId': request_id, 'exitCode': 1}


def main():
    """
    Main worker loop.

    Implements Bazel JSON worker protocol:
    1. Prepare chroot environment (one-time)
    2. Signal ready
    3. Read JSON requests from stdin (one per line)
    4. Process each request
    5. Write JSON responses to stdout (one per line)
    """
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Bazel JSON worker for LFS chroot builds')
    parser.add_argument('--external-dir', help='Path to Bazel external directory')
    args = parser.parse_args()

    try:
        # One-time setup
        prepare_chroot(args.external_dir)

        # Signal ready
        sys.stderr.write("[WORKER] Ready\n")
        sys.stderr.flush()

        # Process requests
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue

            # Debug: log the raw input
            sys.stderr.write(f"[WORKER] Received input: {line[:200]}\n")
            sys.stderr.flush()

            try:
                req = json.loads(line)
                sys.stderr.write(f"[WORKER] Parsed JSON keys: {list(req.keys())}\n")
                sys.stderr.flush()

                resp = process_request(req)

                # Write response
                sys.stdout.write(json.dumps(resp) + '\n')
                sys.stdout.flush()

            except json.JSONDecodeError as e:
                sys.stderr.write(f"[WORKER] Invalid JSON: {e}\n")
                sys.stderr.flush()
            except Exception as e:
                sys.stderr.write(f"[WORKER] Error in main loop: {e}\n")
                sys.stderr.write(f"[WORKER] Line was: {line[:200]}\n")
                sys.stderr.flush()

    except KeyboardInterrupt:
        sys.stderr.write("[WORKER] Interrupted\n")
        sys.stderr.flush()
    except Exception as e:
        sys.stderr.write(f"[WORKER] Fatal error: {e}\n")
        sys.stderr.flush()
        sys.exit(1)


if __name__ == '__main__':
    main()
