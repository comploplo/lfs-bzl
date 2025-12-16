#!/usr/bin/env python3
"""
Unit tests for Bazel JSON Worker.
"""

import json
import os
import unittest
from unittest.mock import MagicMock, patch, mock_open

from tools.podman import worker


class TestBazelWorker(unittest.TestCase):

    def setUp(self):
        self.worker = worker.BazelWorker(external_dir='/external')
        self.worker._mounts = []  # Reset mounts

    @patch('subprocess.run')
    @patch('os.makedirs')
    def test_prepare_chroot(self, mock_makedirs, mock_run):
        self.worker.prepare_chroot()

        # Verify directories created
        self.assertTrue(mock_makedirs.called)

        # Verify mounts
        # We expect calls for /dev, /proc, /sys, /run, /execroot, and external dir
        self.assertTrue(mock_run.called)

        # Check if external dir was mounted
        found_external_mount = False
        for call in mock_run.call_args_list:
            args = call[0][0]
            if args[0] == 'mount' and args[2] == '/external':
                found_external_mount = True
                break
        self.assertTrue(found_external_mount, "External directory not mounted")

    @patch('subprocess.run')
    def test_cleanup_mounts(self, mock_run):
        self.worker._mounts = ['/lfs/dev', '/lfs/proc']
        self.worker.cleanup_mounts()

        # Should unmount in reverse order
        calls = mock_run.call_args_list
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0][0][0], ['umount', '-l', '/lfs/proc'])
        self.assertEqual(calls[1][0][0], ['umount', '-l', '/lfs/dev'])

    @patch('subprocess.run')
    @patch('shutil.copy')
    @patch('os.chmod')
    def test_process_request_success(self, mock_chmod, mock_copy, mock_run):
        # Mock successful build
        mock_run.return_value = MagicMock(returncode=0, stdout='Build output', stderr='')

        # Mock file operations
        with patch('builtins.open', mock_open()) as mock_file:
            with patch('pathlib.Path.touch') as mock_touch:
                req = {
                    'requestId': 123,
                    'arguments': ['--script', 'build.sh', '--done', 'done.marker', '--log', 'build.log']
                }
                resp = self.worker.process_request(req)

                self.assertEqual(resp['exitCode'], 0)
                self.assertEqual(resp['requestId'], 123)

                # Verify script staging
                mock_copy.assert_called()

                # Verify execution
                # Check that we called chroot
                self.assertEqual(mock_run.call_args[0][0][0], 'chroot')

                # Verify marker creation
                mock_touch.assert_called()

    @patch('subprocess.run')
    def test_process_request_failure(self, mock_run):
        # Mock failed build
        mock_run.return_value = MagicMock(returncode=1, stdout='', stderr='Build error')

        with patch('builtins.open', mock_open()):
            req = {
                'requestId': 456,
                'arguments': ['--script', 'build.sh', '--done', 'done.marker', '--log', 'build.log']
            }
            resp = self.worker.process_request(req)

            self.assertEqual(resp['exitCode'], 1)
            self.assertEqual(resp['requestId'], 456)


if __name__ == '__main__':
    unittest.main()
