#!/usr/bin/env python3
"""
Unit tests for Bazel JSON Worker.
"""

import json
import os
import unittest
from unittest.mock import MagicMock, patch, mock_open, call

from tools.podman import worker


class TestBazelWorker(unittest.TestCase):

    def setUp(self):
        self.worker = worker.BazelWorker(external_dir='/external')
        self.worker._mounts = []

    @patch('subprocess.run')
    @patch('os.makedirs')
    def test_prepare_chroot(self, mock_makedirs, mock_run):
        self.worker.prepare_chroot()

        self.assertTrue(mock_makedirs.called)
        self.assertTrue(mock_run.called)

        found_external_mount = False
        for c in mock_run.call_args_list:
            args = c[0][0]
            if args[0] == 'mount' and args[2] == '/external':
                found_external_mount = True
                break
        self.assertTrue(found_external_mount, "External directory not mounted")

    @patch('subprocess.run')
    def test_cleanup_mounts(self, mock_run):
        self.worker._mounts = ['/lfs/dev', '/lfs/proc']
        self.worker.cleanup_mounts()

        calls = mock_run.call_args_list
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0][0][0], ['umount', '-l', '/lfs/proc'])
        self.assertEqual(calls[1][0][0], ['umount', '-l', '/lfs/dev'])

    @patch('subprocess.Popen')
    @patch('shutil.copy')
    @patch('os.chmod')
    def test_process_request_chroot_success(self, mock_chmod, mock_copy, mock_popen):
        mock_proc = MagicMock()
        mock_proc.communicate.return_value = ('Build output', '')
        mock_proc.returncode = 0
        mock_proc.pid = 12345
        mock_popen.return_value = mock_proc

        self.worker._chroot_prepared = True

        with patch('builtins.open', mock_open()) as mock_file:
            with patch('pathlib.Path.touch') as mock_touch:
                with patch('os.path.exists', return_value=True):
                    with patch('subprocess.run'):
                        req = {
                            'requestId': 123,
                            'arguments': [
                                '--mode', 'chroot',
                                '--script', 'build.sh',
                                '--done', 'done.marker',
                                '--log', 'build.log',
                            ]
                        }
                        resp = self.worker.process_request(req)

                        self.assertEqual(resp['exitCode'], 0)
                        self.assertEqual(resp['requestId'], 123)
                        mock_copy.assert_called()
                        mock_touch.assert_called()

    @patch('subprocess.Popen')
    @patch('shutil.copy')
    @patch('os.chmod')
    def test_process_request_chroot_failure(self, mock_chmod, mock_copy, mock_popen):
        mock_proc = MagicMock()
        mock_proc.communicate.return_value = ('', 'Build error')
        mock_proc.returncode = 1
        mock_proc.pid = 12345
        mock_popen.return_value = mock_proc

        self.worker._chroot_prepared = True

        with patch('builtins.open', mock_open()):
            req = {
                'requestId': 456,
                'arguments': [
                    '--mode', 'chroot',
                    '--script', 'build.sh',
                    '--done', 'done.marker',
                    '--log', 'build.log',
                ]
            }
            resp = self.worker.process_request(req)

            self.assertEqual(resp['exitCode'], 1)
            self.assertEqual(resp['requestId'], 456)

    @patch('subprocess.Popen')
    def test_process_request_container_mode(self, mock_popen):
        mock_proc = MagicMock()
        mock_proc.communicate.return_value = ('Build output', '')
        mock_proc.returncode = 0
        mock_proc.pid = 12345
        mock_popen.return_value = mock_proc

        with patch('builtins.open', mock_open()):
            with patch('pathlib.Path.touch'):
                req = {
                    'requestId': 789,
                    'arguments': [
                        '--mode', 'container',
                        '--script', 'build.sh',
                        '--done', 'done.marker',
                        '--log', 'build.log',
                    ]
                }
                resp = self.worker.process_request(req)

                self.assertEqual(resp['exitCode'], 0)
                self.assertEqual(resp['requestId'], 789)

                cmd = mock_popen.call_args[0][0]
                self.assertEqual(cmd[0], '/usr/bin/env')
                self.assertNotIn('chroot', cmd)

                env_strs = [a for a in cmd if a.startswith('LFS=')]
                self.assertEqual(env_strs, ['LFS=/lfs'])

    @patch('subprocess.Popen')
    def test_container_mode_no_chroot_setup(self, mock_popen):
        mock_proc = MagicMock()
        mock_proc.communicate.return_value = ('ok', '')
        mock_proc.returncode = 0
        mock_proc.pid = 12345
        mock_popen.return_value = mock_proc

        self.assertFalse(self.worker._chroot_prepared)

        with patch('builtins.open', mock_open()):
            with patch('pathlib.Path.touch'):
                req = {
                    'requestId': 1,
                    'arguments': [
                        '--mode', 'container',
                        '--script', 'build.sh',
                        '--done', 'done.marker',
                        '--log', 'build.log',
                    ]
                }
                self.worker.process_request(req)

        self.assertFalse(self.worker._chroot_prepared)

    @patch('subprocess.run')
    @patch('os.makedirs')
    @patch('subprocess.Popen')
    @patch('shutil.copy')
    @patch('os.chmod')
    def test_lazy_chroot_setup(self, mock_chmod, mock_copy, mock_popen, mock_makedirs, mock_run):
        mock_proc = MagicMock()
        mock_proc.communicate.return_value = ('ok', '')
        mock_proc.returncode = 0
        mock_proc.pid = 12345
        mock_popen.return_value = mock_proc

        self.assertFalse(self.worker._chroot_prepared)

        with patch('builtins.open', mock_open()):
            with patch('pathlib.Path.touch'):
                with patch('os.path.exists', return_value=True):
                    req = {
                        'requestId': 1,
                        'arguments': [
                            '--mode', 'chroot',
                            '--script', 'build.sh',
                            '--done', 'done.marker',
                            '--log', 'build.log',
                        ]
                    }
                    self.worker.process_request(req)

        self.assertTrue(self.worker._chroot_prepared)
        self.assertTrue(mock_makedirs.called)

    def test_parse_args_container_mode(self):
        args = self.worker.parse_args([
            '--mode', 'container',
            '--script', 'test.sh',
            '--done', 'test.done',
            '--log', 'test.log',
        ])
        self.assertEqual(args.mode, 'container')
        self.assertEqual(args.script, 'test.sh')

    def test_parse_args_chroot_mode(self):
        args = self.worker.parse_args([
            '--mode', 'chroot',
            '--script', 'test.sh',
            '--done', 'test.done',
            '--log', 'test.log',
        ])
        self.assertEqual(args.mode, 'chroot')

    def test_parse_args_invalid_mode(self):
        with self.assertRaises(SystemExit):
            self.worker.parse_args([
                '--mode', 'invalid',
                '--script', 'test.sh',
                '--done', 'test.done',
                '--log', 'test.log',
            ])

    def test_resolve_path_absolute(self):
        self.assertEqual(self.worker._resolve_path('/abs/path'), '/abs/path')

    def test_resolve_path_relative(self):
        self.assertEqual(self.worker._resolve_path('rel/path'), '/execroot/rel/path')


if __name__ == '__main__':
    unittest.main()
