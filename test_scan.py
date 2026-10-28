"""Regression checks for streaming, depth limits, filtering, and cancellation."""
import json
from pathlib import Path
import select
import subprocess
import tempfile
import unittest

HELPER = Path(__file__).with_name('config.rb')
CONFIG = '''apiVersion: v1
clusters:
- name: dev
  cluster:
    server: https://example.invalid
contexts:
- name: development
  context:
    cluster: dev
current-context: development
'''


class ScanTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def write(self, path, content=CONFIG):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        return target

    def scan(self, depth=3):
        result = subprocess.run(['/usr/bin/ruby', str(HELPER), 'scan', str(self.root), str(depth)],
                                check=True, capture_output=True, text=True, timeout=10)
        return [json.loads(line) for line in result.stdout.splitlines()]

    def paths(self, events):
        return {Path(e['config']['path']).relative_to(self.root).as_posix()
                for e in events if e['type'] == 'config'}

    def test_depth_and_unlimited(self):
        self.write('root-config')
        self.write('one/config')
        self.write('one/two/config')
        self.assertEqual(self.paths(self.scan(1)), {'root-config', 'one/config'})
        self.assertEqual(len(self.paths(self.scan(-1))), 3)

    def test_hidden_cache_backups_symlinks_and_large_files(self):
        self.write('.kube/config')
        for path in ['.secret/config', 'node_modules/config', 'Library/config',
                     'config.kubeswitch-backup-123', 'binary.png']:
            self.write(path)
        target = self.write('real-config')
        (self.root / 'linked').symlink_to(target)
        self.write('too-large', '# ' + 'x' * 2_000_001 + '\n' + CONFIG)
        self.assertEqual(self.paths(self.scan()), {'.kube/config', 'real-config'})

    def test_late_fields_invalid_yaml_and_non_ascii(self):
        self.write('cấu-hình.yaml', '# ' + 'x' * 10000 + '\n' + CONFIG)
        self.write('broken.yaml', 'clusters: [\ncontexts: [')
        self.write('weird.yaml', 'clusters: []\ncontexts: [null, 42, {}]\n')
        events = self.scan()
        self.assertEqual(self.paths(events), {'cấu-hình.yaml'})
        self.assertEqual(events[-1]['type'], 'done')
        self.assertEqual(events[-1]['checked'], 3)

    def test_streaming_and_termination(self):
        # Keep real work pending after the first streamed result.
        self.write('00-kubeconfig')
        for i in range(5000):
            self.write(f'bulk/file-{i:05d}', 'ordinary text\n')
        process = subprocess.Popen(['/usr/bin/ruby', str(HELPER), 'scan', str(self.root), '-1'],
                                   stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        try:
            # os.read avoids buffering an entire output stream before checking readiness.
            import os
            data = b''
            while b'"type":"config"' not in data:
                self.assertTrue(select.select([process.stdout], [], [], 5)[0], 'no streaming event')
                chunk = os.read(process.stdout.fileno(), 4096)
                self.assertTrue(chunk, 'stream ended before config')
                data += chunk
            self.assertNotIn(b'"type":"done"', data)
            process.terminate()
            process.wait(timeout=2)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=2)
            process.stdout.close()

    def test_missing_folder_fails(self):
        result = subprocess.run(['/usr/bin/ruby', str(HELPER), 'scan', str(self.root / 'missing'), '3'],
                                capture_output=True, timeout=5)
        self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
