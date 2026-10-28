"""Exercise real Sparkle feed checking without installing or touching kubeconfig."""
import functools
import http.server
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import threading
import uuid
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent


def main():
    with tempfile.TemporaryDirectory(prefix='kubeswitch-update-test-') as temporary:
        work = Path(temporary)
        # Compile a disposable app using Sparkle's real update-checking APIs.
        executable = work / 'probe'
        subprocess.run(['swiftc', '-swift-version', '5', str(ROOT / 'tests/UpdateProbe.swift'),
                        '-F', str(ROOT / '.dependencies'), '-framework', 'Sparkle',
                        '-framework', 'Cocoa', '-Xlinker', '-rpath', '-Xlinker',
                        str(ROOT / '.dependencies'), '-o', str(executable)], check=True)
        feed = (ROOT / 'appcast.xml').read_bytes()
        (work / 'valid.xml').write_bytes(feed)
        (work / 'tampered.xml').write_bytes(feed.replace(b'<title>KubeSwitch</title>',
                                                       b'<title>KubeSwitcz</title>'))
        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(work))
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            for filename, reject in [('valid.xml', False), ('tampered.xml', True)]:
                bundle = work / ('Reject.app' if reject else 'Accept.app')
                binary = bundle / 'Contents/MacOS/KubeSwitch'
                binary.parent.mkdir(parents=True)
                shutil.copy2(executable, binary)
                info = plistlib.loads((ROOT / 'Info.plist').read_bytes())
                info.update(CFBundleIdentifier='local.kubeswitch.probe.' + uuid.uuid4().hex,
                            CFBundleVersion='2', CFBundleShortVersionString='1.1.0',
                            SUFeedURL=f'http://127.0.0.1:{server.server_port}/{filename}',
                            SUEnableAutomaticChecks=False,
                            NSAppTransportSecurity={'NSAllowsLocalNetworking': True})
                (bundle / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
                subprocess.run(['codesign', '--force', '--sign', '-', str(bundle)], check=True)
                result = subprocess.run([str(binary)] + (['--reject'] if reject else []),
                                        capture_output=True, text=True, timeout=30)
                print(result.stdout, end='')
                if result.returncode:
                    print(result.stderr)
                    raise RuntimeError(f'{filename}: probe failed ({result.returncode})')
            # Verify the exact archive signature, then reject a modified archive.
            xml = ET.fromstring(feed)
            enclosure = xml.find('./channel/item/enclosure')
            signature = enclosure.attrib['{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature']
            verifier = ROOT / '.dependencies/bin/sign_update'
            archive = ROOT / 'dist/KubeSwitch-macOS.zip'
            command = [str(verifier), '--account', 'hieupnvmg.KubeSwitch', '--verify']
            subprocess.run(command + [str(archive), signature], check=True)
            altered = work / 'altered.zip'
            changed = bytearray(archive.read_bytes())
            changed[len(changed) // 2] ^= 1
            altered.write_bytes(changed)
            result = subprocess.run(command + [str(altered), signature], capture_output=True)
            assert result.returncode != 0, 'modified archive was accepted'
            print('PASS: signed feed accepted; modified feed and archive rejected.')
        finally:
            server.shutdown()
            server.server_close()


if __name__ == '__main__':
    main()
