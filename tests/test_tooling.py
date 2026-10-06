"""Regression tests for installation, scanning, data snapshots and generated workflows."""
from __future__ import annotations

import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class Workspace(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.work = Path(self.tmp.name)
        self.env = dict(os.environ)
        self.env['GIT_CONFIG_NOSYSTEM'] = '1'
        self.env['GIT_CONFIG_GLOBAL'] = os.devnull
        for agent in ('CODEX', 'CLAUDE', 'OPENCODE'):
            self.env[agent + '_SKILLS_DIR'] = str(self.work / agent.lower())

    def run_cli(self, *args, code=0, env=None):
        command = list(map(str, args))
        if os.name == 'nt' and command[0] == 'bash':
            command = [arg.replace('\\', '/') for arg in command]
        proc = subprocess.run(command, cwd=self.work,
                              env=env or self.env, capture_output=True, text=True, encoding='utf-8', timeout=20)
        self.assertEqual(proc.returncode, code, proc.stdout + proc.stderr)
        return proc

    def fake_gh(self):
        binary = self.work / 'bin'
        binary.mkdir()
        gh = binary / 'gh'
        shutil.copyfile(ROOT / 'tests/fixtures/gh.py', gh)
        gh.chmod(0o755)
        self.env['PATH'] = str(binary) + os.pathsep + self.env['PATH']
        self.env['GH_TEST_LOG'] = str(self.work / 'gh.log')
        self.env['GH_TEST_DATA'] = str(self.work / 'data.json')

    def gh_calls(self):
        return [json.loads(line) for line in (self.work / 'gh.log').read_text().splitlines()]


@unittest.skipIf(os.name == 'nt', 'Windows installer is covered by the PowerShell CI step')
class InstallerTests(Workspace):
    def test_all_clients_idempotent(self):
        for _ in range(2):
            self.run_cli('bash', ROOT / 'install.sh')
        expected = len(list((ROOT / 'skills').glob('*/SKILL.md')))
        for agent in ('codex', 'claude', 'opencode'):
            links = list((self.work / agent).iterdir())
            self.assertEqual(len(links), expected)
            self.assertTrue(all(link.is_symlink() and (link / 'SKILL.md').is_file() for link in links))

    def test_dry_run_and_selection(self):
        self.run_cli('bash', ROOT / 'install.sh', '--dry-run', '--agent', 'codex', 'kit-capture')
        self.assertFalse((self.work / 'codex').exists())
        self.run_cli('bash', ROOT / 'install.sh', '--agent', 'codex', 'kit-capture')
        self.assertTrue((self.work / 'codex/kit-capture').is_symlink())
        self.assertFalse((self.work / 'claude').exists())

    def test_validate_batch_before_installing(self):
        self.run_cli('bash', ROOT / 'install.sh', 'kit-capture', 'missing', code=2)
        self.assertFalse((self.work / 'codex').exists())

    def test_conflict_keeps_real_directory(self):
        target = self.work / 'codex/kit-capture'
        target.mkdir(parents=True)
        (target / 'keep').write_text('existing')
        self.run_cli('bash', ROOT / 'install.sh', '--agent', 'codex', 'kit-capture', code=1)
        self.assertEqual((target / 'keep').read_text(), 'existing')

    def test_replace_link_preserves_old_target(self):
        target = self.work / 'codex'
        target.mkdir()
        original = self.work / 'old'
        original.mkdir()
        (original / 'keep').write_text('keep')
        (target / 'kit-capture').symlink_to(original, target_is_directory=True)
        self.run_cli('bash', ROOT / 'install.sh', '--agent', 'codex', 'kit-capture')
        self.assertEqual((original / 'keep').read_text(), 'keep')
        self.assertEqual((target / 'kit-capture').resolve(), ROOT / 'skills/kit-capture')


class DiagnosisTests(Workspace):
    @unittest.skipIf(os.name == 'nt', 'POSIX symlink fixture')
    def test_miniapp_routes_tests_symlinks_and_json_file(self):
        # The absolute parent contains "tests"; it must not exclude production files.
        project = self.work / 'tests/project'
        (project / 'wx/views').mkdir(parents=True)
        (project / 'wx/app.json').write_text(json.dumps({'pages': ['views/home']}))
        (project / 'wx/views/home.wxml').write_text('<view/>')
        (project / 'wx/app.wxss').write_text('color:#fff;')
        for excluded in ('node_modules', 'tests', 'fixtures'):
            (project / excluded).mkdir()
            (project / excluded / 'game.json').write_text('{}')
            (project / excluded / 'bad.wxss').write_text('color:#abc;')
        external = self.work / 'external'
        external.mkdir()
        (external / 'leak.wxss').write_text('color:#000;')
        (project / 'linked').symlink_to(external, target_is_directory=True)
        proc = self.run_cli(sys.executable, ROOT / 'skills/kit-wechat-miniapp-ui-optimizer/scripts/diagnose.py',
                            project, '--json', '--out', self.work / 'report.json')
        report = json.loads(proc.stdout)
        self.assertEqual(report, json.loads((self.work / 'report.json').read_text()))
        self.assertEqual(report['page_count'], 1)
        self.assertEqual(report['source_metrics']['candidate_hardcoded_color_occurrences'], 1)
        self.assertFalse(report['entry_files']['game_json'])

    def test_game_typescript_and_excluded_resources(self):
        project = self.work / 'game'
        project.mkdir()
        (project / 'game.ts').write_text('ctx.fillText("score",0,0);')
        (project / 'tests').mkdir()
        (project / 'tests/fake.png').write_bytes(b'not-production')
        proc = self.run_cli(sys.executable, ROOT / 'skills/kit-wechat-minigame-ui-optimizer/scripts/diagnose.py',
                            project, '--json')
        report = json.loads(proc.stdout)
        self.assertEqual(report['project_type'], '微信小游戏（Canvas）')
        self.assertEqual(report['image_files'], 0)
        self.assertEqual(report['canvas_draw_keyword_occurrences'], 1)


class GithubTests(Workspace):
    def setUp(self):
        super().setUp()
        self.fake_gh()

    def test_failed_fetch_preserves_snapshot(self):
        for skill, script in [('kit-gh-stars', 'fetch-stars.sh'), ('kit-project-hub', 'fetch-repos.sh')]:
            output = self.work / 'saved.json'
            output.write_text('previous')
            self.run_cli('bash', ROOT / 'skills' / skill / 'scripts' / script, 'tester', output,
                         code=1, env={**self.env, 'GH_TEST_FAIL': '1'})
            self.assertEqual(output.read_text(), 'previous')
            self.assertFalse(list(self.work.glob('saved.json.tmp.*')))

    def test_public_paginated_repos_excludes_private_and_forks(self):
        rows = [{'name': f'r{i}', 'private': False, 'fork': False} for i in range(1100)]
        rows += [{'name': 'private', 'private': True}, {'name': 'fork', 'private': False, 'fork': True}]
        Path(self.env['GH_TEST_DATA']).write_text(json.dumps(rows))
        output = self.work / 'repos.json'
        script = ROOT / 'skills/kit-project-hub/scripts/fetch-repos.sh'
        self.run_cli('bash', script, 'tester', output)
        self.assertEqual(len(json.loads(output.read_text())), 1100)
        self.run_cli('bash', script, 'tester', output, '--include-forks')
        result = json.loads(output.read_text())
        self.assertEqual(len(result), 1101)
        self.assertNotIn('private', {row['name'] for row in result})
        self.assertTrue(any('--paginate' in call and '--slurp' in call for call in self.gh_calls()))

    def test_pages_dry_run_is_read_only_and_lockfile_aware(self):
        self.env['GH_TEST_PACKAGE'] = json.dumps({'scripts': {'build': 'vite build'}})
        self.env['GH_TEST_FILES'] = 'package-lock.json'
        script = ROOT / 'skills/kit-gh-pages/scripts/setup-pages.sh'
        proc = self.run_cli('bash', script, 'tester/site', '--dry-run', '--branch', 'release/docs')
        self.assertIn('npm ci', proc.stdout)
        self.assertIn('cache: npm', proc.stdout)
        self.assertIn('branches: ["release/docs"]', proc.stdout)
        self.assertTrue(all('-X' not in call for call in self.gh_calls()))
        self.assertTrue(any('ref=release%2Fdocs' in arg for call in self.gh_calls() for arg in call))

    def test_pages_without_lockfile_uses_install_and_actual_url(self):
        self.env['GH_TEST_PACKAGE'] = json.dumps({'scripts': {'build': 'vite build'}})
        script = ROOT / 'skills/kit-gh-pages/scripts/setup-pages.sh'
        proc = self.run_cli('bash', script, 'tester/site', '--dry-run')
        self.assertIn('npm install', proc.stdout)
        self.assertNotIn('cache: npm', proc.stdout)
        proc = self.run_cli('bash', script, 'tester/site')
        self.assertIn('https://example.test/custom', proc.stdout)

    def test_invalid_pages_args_do_not_call_gh(self):
        script = ROOT / 'skills/kit-gh-pages/scripts/setup-pages.sh'
        for args in [('--mode',), ('--dir', 'other'), ('--mode', 'bad')]:
            self.run_cli('bash', script, 'tester/site', *args, code=2)
        self.assertFalse((self.work / 'gh.log').exists())


class WorkflowTests(Workspace):
    def test_preserves_existing_workflow_and_handles_worktree(self):
        for skill, workflow in [('kit-gh-stars', 'sync-stars.yml'), ('kit-project-hub', 'audit-weekly.yml')]:
            project = self.work / skill
            source = self.work / (skill + '-source')
            source.mkdir()
            self.run_cli('git', '-C', source, 'init', '-b', 'main')
            self.run_cli('git', '-C', source, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
                         'commit', '--allow-empty', '-m', 'fixture')
            self.run_cli('git', '-C', source, 'worktree', 'add', '-b', 'release', project)
            self.assertTrue((project / '.git').is_file())
            script = ROOT / 'skills' / skill / 'scripts/setup-ci.sh'
            self.run_cli('bash', script, project)
            path = project / '.github/workflows' / workflow
            content = path.read_text()
            self.assertIn('ref: "release"', content)
            self.assertIn('data/desc_zh.json', content)
            path.write_text('custom-workflow')
            self.run_cli('bash', script, project)
            self.assertEqual(path.read_text(), 'custom-workflow')
            self.run_cli('bash', script, project, '--force')
            self.assertNotEqual(path.read_text(), 'custom-workflow')
            self.run_cli('bash', script, '--unknown', code=2)


class CaptureTests(Workspace):
    def test_argument_errors_fail_before_runtime(self):
        script = ROOT / 'skills/kit-capture/scripts/capture.sh'
        for args in [(), ('browser',), ('browser', 'https://example.com', '-o'),
                     ('interact', 'https://example.com', '--width', '1.5'),
                     ('interact', 'https://example.com', '--dsf', '0'),
                     ('screen', '--height', '100'), ('browser', 'https://example.com', '--width', '0')]:
            self.run_cli('bash', script, *args, code=2)

    @unittest.skipIf(os.name == 'nt', 'POSIX executable fixture')
    def test_capture_is_atomic_and_creates_parent(self):
        browser = self.work / 'chrome'
        browser.write_text('#!/usr/bin/env python3\nimport os,shutil,sys\n'
                           'if os.environ.get("CAPTURE_FAIL"): sys.exit(1)\n'
                           'out=next(a.split("=",1)[1] for a in sys.argv if a.startswith("--screenshot="))\n'
                           'shutil.copyfile(os.environ["CAPTURE_PNG"],out)\n')
        browser.chmod(0o755)
        env = {**self.env, 'KIT_SHOTFRAME_CHROMIUM': str(browser),
               'CAPTURE_PNG': str(ROOT / 'docs/screenshots/browser-example.png')}
        output = self.work / 'nested/page.png'
        script = ROOT / 'skills/kit-capture/scripts/capture.sh'
        self.run_cli('bash', script, 'browser', 'https://example.com', '-o', output, env=env)
        previous = output.read_bytes()
        self.run_cli('bash', script, 'browser', 'https://example.com', '-o', output,
                     env={**env, 'CAPTURE_FAIL': '1'}, code=1)
        self.assertEqual(output.read_bytes(), previous)
        self.assertFalse(list(output.parent.glob('.kit-capture.*')))

    def test_frame_cli_rejects_typos_and_supports_output_alias(self):
        script = ROOT / 'skills/kit-shotframe/scripts/frame.js'
        proc = self.run_cli('node', script, '--list', '--json')
        self.assertTrue(json.loads(proc.stdout)['ok'])
        for flags, expected in [(('--unknown',), 'config/unknown-option'),
                                (('--padding',), 'config/missing-value'),
                                (('--bg', 'nope'), 'config/unknown-background')]:
            proc = self.run_cli('node', script, '--input', ROOT / 'docs/screenshots/browser-example.png',
                                '-o', self.work / 'out.png', '--json', *flags, code=2)
            self.assertEqual(json.loads(proc.stdout)['error']['code'], expected)

    @unittest.skipIf(os.name == 'nt', 'POSIX executable fixture')
    def test_frame_zero_exit_without_output_preserves_previous_image(self):
        browser = self.work / 'ghost-browser'
        browser.write_text('#!/bin/sh\nexit 0\n')
        browser.chmod(0o755)
        output = self.work / 'previous.png'
        original = (ROOT / 'docs/screenshots/browser-example.png').read_bytes()
        output.write_bytes(original)
        proc = self.run_cli('node', ROOT / 'skills/kit-shotframe/scripts/frame.js',
                            '--input', output, '--output', output, '--chromium', browser, '--json', code=1)
        self.assertEqual(json.loads(proc.stdout)['error']['code'], 'output/missing')
        self.assertEqual(output.read_bytes(), original)
        self.assertFalse(list(self.work.glob('.kit-shotframe-*')))


class GeneratorTests(Workspace):
    def test_generators_accept_sparse_data_and_escape_content(self):
        for skill, script, rows, extra in [
            ('kit-gh-stars', 'gen-index.py', [{'full_name': 'a/b', 'description': '<b>hello</b>',
             'stargazers_count': '1.2k', 'topics': ['ai']}], []),
            ('kit-project-hub', 'gen-hub.py', [{'name': 'r1', 'description': '<b>hello</b>',
             'stargazersCount': '1.2k', 'updatedAt': '<script>', 'url': 'javascript:alert(1)'},
             {'description': 'no-name'}], ['--featured', 'r1,r1'])]:
            data, out = self.work / 'input.json', self.work / 'page.html'
            data.write_text(json.dumps(rows))
            self.run_cli(sys.executable, ROOT / 'skills' / skill / 'scripts' / script,
                         data, out, '--owner', 'tester', *extra)
            content = out.read_text()
            self.assertIn('class="card"', content)
            self.assertIn('&lt;b&gt;hello&lt;/b&gt;', content)
            self.assertNotIn('javascript:alert', content)
            if skill == 'kit-project-hub':
                self.assertEqual(content.count('class="card"'), 1)
                self.assertIn('href="https://github.com/tester/r1"', content)

    def test_jsonl_bad_line_does_not_drop_valid_record(self):
        data, out = self.work / 'input.jsonl', self.work / 'page.html'
        data.write_text('invalid\n' + json.dumps({'full_name': 'a/b', 'topics': []}) + '\n')
        self.run_cli(sys.executable, ROOT / 'skills/kit-gh-stars/scripts/gen-index.py', data, out)
        self.assertIn('https://github.com/a/b', out.read_text())


class SkillValidationTests(Workspace):
    def test_copied_skill_validates_independently_and_detects_missing_resource(self):
        copy = self.work / 'kit-capture'
        shutil.copytree(ROOT / 'skills/kit-capture', copy)
        validator = ROOT / 'tools/validate_skills.py'
        self.run_cli(sys.executable, validator, '--skill', copy)
        self.run_cli('bash', copy / 'scripts/capture.sh', '--help')
        (copy / 'references/platforms.md').unlink()
        self.run_cli(sys.executable, validator, '--skill', copy, code=1)

    def test_directory_and_metadata_mismatch_fails(self):
        copy = self.work / 'kit-renamed'
        shutil.copytree(ROOT / 'skills/kit-capture', copy)
        self.run_cli(sys.executable, ROOT / 'tools/validate_skills.py', '--skill', copy, code=1)


if __name__ == '__main__':
    unittest.main()
