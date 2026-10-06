#!/usr/bin/env python3
"""Render local fixtures with real Chromium; never access a live web page."""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main():
    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        command = ['node', str(ROOT / 'skills/kit-shotframe/scripts/frame.js'), '--input',
                   str(ROOT / 'docs/screenshots/browser-example.png'), '--preset', 'browser',
                   '--ratio', 'og', '--width', '600', '--output', str(work / 'og.png'), '--json']
        chromium = os.environ.get('CHROME_BIN')
        if chromium:
            command += ['--chromium', chromium]
        proc = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', timeout=90)
        if proc.returncode:
            print(proc.stdout + proc.stderr, file=sys.stderr)
            return 1
        receipt = json.loads(proc.stdout)
        output = receipt['outputs'][0]
        assert receipt['ok'] and output['width'] == 600, receipt
        assert abs(output['width'] / output['height'] - 1.91) < 0.05, receipt
        from PIL import Image
        with Image.open(work / 'og.png') as im:
            im.load()
            assert im.size == (output['width'], output['height'])
            assert any(lo != hi for lo, hi in im.convert('RGB').getextrema()), 'blank rendered image'
        transparent_command = ['node', str(ROOT / 'skills/kit-shotframe/scripts/frame.js'),
                               '--input', str(ROOT / 'docs/screenshots/device-iphone.png'),
                               '--preset', 'macos', '--transparent', '--output', str(work / 'alpha.png'), '--json']
        if chromium:
            transparent_command += ['--chromium', chromium]
        alpha = subprocess.run(transparent_command, capture_output=True, text=True, timeout=90)
        assert alpha.returncode == 0, alpha.stdout + alpha.stderr
        with Image.open(work / 'alpha.png') as im:
            im.load()
            assert im.mode == 'RGBA' and im.getpixel((0, 0))[3] == 0, 'missing transparency'
        page = work / 'fixture.html'
        page.write_text('<html><body><h1>Local capture fixture</h1></body></html>', encoding='utf-8')
        env = dict(os.environ)
        if chromium:
            env['KIT_SHOTFRAME_CHROMIUM'] = chromium
        subprocess.run(['bash', str(ROOT / 'skills/kit-capture/scripts/capture.sh'), 'browser',
                        page.as_uri(), '-o', str(work / 'nested/capture.png')], env=env, check=True, timeout=60)
        with Image.open(work / 'nested/capture.png') as im:
            im.load()
            assert im.width == 1440
        print('✅ Chromium：真实套框尺寸、PNG 解码、本地网页截图通过')
        return 0


if __name__ == '__main__':
    raise SystemExit(main())
