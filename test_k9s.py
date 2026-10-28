"""Test the launcher with a fake k9s. Does not connect to any cluster."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent


class K9sTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='kubeswitch-k9s-')
        cls.root = Path(cls.temp.name)
        cls.probe = cls.root / 'probe'
        subprocess.run(['swiftc', str(ROOT / 'K9sLaunch.swift'),
                        str(ROOT / 'tests/K9sScriptProbe.swift'), '-o', str(cls.probe)], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_exact_arguments_cwd_and_shell_escaping(self):
        directory = self.root / "team ' $(touch injected-dir)"
        directory.mkdir()
        config = directory / "config ' ; touch injected-file ;.yaml"
        config.write_text('fixture')
        context = "--prod ' $(touch injected-context) `touch injected-backtick`\nsecond line"
        launch = self.root / 'launch.command'
        subprocess.run([str(self.probe), str(launch), str(config), context], check=True)
        binary_dir = self.root / 'bin'
        binary_dir.mkdir()
        fake = binary_dir / 'k9s'
        fake.write_text('''#!/bin/zsh
printf '%s\\0' "$PWD" "$@" > "$K9S_TEST_CAPTURE"
''')
        fake.chmod(0o700)
        capture = self.root / 'args.bin'
        env = dict(os.environ, PATH=str(binary_dir) + ':/usr/bin:/bin', K9S_TEST_CAPTURE=str(capture))
        subprocess.run(['/bin/zsh', str(launch)], cwd=self.root, env=env, check=True, timeout=5)
        args = capture.read_bytes().decode().split('\0')[:-1]
        self.assertEqual(args, [str(directory), '--kubeconfig=' + str(config), '--context=' + context])
        self.assertFalse(launch.exists(), 'temporary script should remove itself')
        for path in list(self.root.glob('injected-*')) + list(directory.glob('injected-*')):
            self.fail('shell injection created ' + str(path))
        self.assertEqual(config.read_text(), 'fixture')

    def test_missing_k9s_shows_install_hint(self):
        # Restrict PATH after the generated export so this test works on hosts with k9s.
        launch = self.root / 'missing.command'
        subprocess.run([str(self.probe), str(launch), str(self.root / 'config'), 'dev'], check=True)
        script = launch.read_text().replace('export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"',
                                          'export PATH="/usr/bin:/bin"')
        launch.write_text(script)
        result = subprocess.run(['/bin/zsh', str(launch)], input='\n', text=True,
                                capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 127)
        self.assertIn('brew install k9s', result.stdout)
        self.assertFalse(launch.exists())


if __name__ == '__main__':
    unittest.main()
