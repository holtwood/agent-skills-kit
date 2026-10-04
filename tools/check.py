#!/usr/bin/env python3
"""Run repository validation, syntax checks and offline regressions; --render adds browsers."""
from __future__ import annotations

import argparse
import ast
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run(command, env=None):
    if os.name == 'nt' and command[0] == 'bash':
        command = [str(arg).replace('\\', '/') for arg in command]
    print("→ " + " ".join(str(arg) for arg in command), flush=True)
    subprocess.run(command, cwd=ROOT, env=env, check=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--render", action="store_true", help="运行真实浏览器测试；需可用 Chromium")
    args = parser.parse_args()
    try:
        run([sys.executable, "tools/validate_skills.py"])
        for path in sorted(ROOT.rglob("*.py")):
            if ".git" not in path.parts and "node_modules" not in path.parts:
                ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        for path in [ROOT / "install.sh", *sorted((ROOT / "skills").glob("*/scripts/*.sh"))]:
            run(["bash", "-n", str(path)])
            run(["bash", str(path), "--help"])
        for path in sorted((ROOT / "skills").glob("*/scripts/*.py")):
            run([sys.executable, str(path), "--help"])
        for path in sorted((ROOT / "skills").glob("*/scripts/*")):
            if path.suffix in {".js", ".cjs"}:
                run(["node", "--check", str(path)])
        run(["node", "--test", *map(str, sorted((ROOT / "skills/kit-shotframe/test").glob("*.test.cjs")))])
        run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-v"])
        env = dict(os.environ)
        if not args.render:
            env["KIT_SKIP_BROWSER_TESTS"] = "1"
        else:
            env.pop("KIT_SKIP_BROWSER_TESTS", None)
        run([sys.executable, "skills/kit-gzh-article-pipeline/tests/regression.py"], env=env)
        if args.render:
            run([sys.executable, "tests/render_smoke.py"])
    except (OSError, SyntaxError, subprocess.CalledProcessError) as exc:
        print(f"✗ 检查失败: {exc}", file=sys.stderr)
        return 1
    print("✅ 仓库检查通过")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
