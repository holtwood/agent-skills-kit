#!/usr/bin/env python3
"""Offline gh double: record calls; fixture data and failures come from environment."""
import base64
import json
import os
import sys
from pathlib import Path

args = sys.argv[1:]
with open(os.environ["GH_TEST_LOG"], "a", encoding="utf-8") as log:
    log.write(json.dumps(args) + "\n")
if args[:2] == ["auth", "status"]:
    raise SystemExit(0)
if os.environ.get("GH_TEST_FAIL"):
    print('partial')
    raise SystemExit(1)
if args[0] != "api":
    raise SystemExit(1)
endpoint = next((arg for arg in args[1:] if arg == "user" or arg.startswith(("users/", "orgs/", "repos/"))), "")
if endpoint == "user":
    print('tester')
elif endpoint == "repos/tester/site":
    print(json.dumps({"default_branch": "main", "fork": False}))
elif "/contents/" in endpoint:
    target = endpoint.split('/contents/', 1)[1].split('?', 1)[0]
    if target == 'package.json' and os.environ.get('GH_TEST_PACKAGE'):
        print(base64.b64encode(os.environ['GH_TEST_PACKAGE'].encode()).decode())
    elif target in os.environ.get('GH_TEST_FILES', '').split(','):
        print('fixture-sha')
    elif '-X' in args:
        print('{}')
    else:
        raise SystemExit(1)
elif endpoint.endswith('/pages'):
    print('https://example.test/custom' if '.html_url // empty' in args else 'built')
elif endpoint.endswith('/starred?per_page=100') or '/repos?' in endpoint:
    print(Path(os.environ['GH_TEST_DATA']).read_text(encoding='utf-8'))
elif endpoint.startswith('users/'):
    print('User')
else:
    raise SystemExit(1)
