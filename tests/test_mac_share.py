import pathlib
import runpy
import subprocess
import unittest
from unittest.mock import patch

SCRIPT = pathlib.Path(__file__).parents[1] / 'scripts' / 'setup-mac-share.py'

class BeforeCredentials(Exception):
    pass

class MacShareConnectivity(unittest.TestCase):
    def test_relay_accepted_and_real_smb_checked_before_credentials(self):
        with patch('os.geteuid', return_value=0), patch('builtins.input', side_effect=['100.64.0.2', 'Claude-Shared', 'claudeshare']), patch('subprocess.run') as run, patch('socket.create_connection') as connect, patch('getpass.getpass', side_effect=BeforeCredentials):
            with self.assertRaises(BeforeCredentials):
                runpy.run_path(str(SCRIPT), run_name='__main__')
            self.assertIn('--until-direct=false', run.call_args.args[0])
            connect.assert_called_once_with(('100.64.0.2', 445), timeout=15)

    def test_unreachable_smb_stops_before_credentials(self):
        with patch('os.geteuid', return_value=0), patch('builtins.input', return_value='100.64.0.2'), patch('subprocess.run'), patch('socket.create_connection', side_effect=TimeoutError), patch('getpass.getpass') as password:
            with self.assertRaisesRegex(SystemExit, 'No credentials or mount settings were changed'):
                runpy.run_path(str(SCRIPT), run_name='__main__')
            password.assert_not_called()

    def test_no_tailnet_response_stops_before_smb(self):
        with patch('os.geteuid', return_value=0), patch('builtins.input', return_value='100.64.0.2'), patch('subprocess.run', side_effect=subprocess.CalledProcessError(1, ['tailscale'])), patch('socket.create_connection') as connect, patch('getpass.getpass') as password:
            with self.assertRaises(SystemExit):
                runpy.run_path(str(SCRIPT), run_name='__main__')
            connect.assert_not_called()
            password.assert_not_called()
