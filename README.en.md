# agent-skills-kit

> Installable Agent Skills for a solo developer's showcase pipeline: **capture → polish → publish → present**. Chinese docs; works with opencode / Claude Code / Codex.
>
> **中文**: [README.md](./README.md)

## Skills

| Skill | What it does |
| --- | --- |
| [`kit-capture`](./skills/kit-capture/) | Cross-platform screenshots (Win/macOS/Linux/WSL): desktop / windows / web pages / clipboard with multi-backend fallback; `interact` mode clicks, waits, and captures elements |
| [`kit-shotframe`](./skills/kit-shotframe/) | Screenshot framing: browser / macOS / iPhone / Galaxy frames, social & app-store canvas ratios, copy layer, vector PDF |
| [`kit-gh-pages`](./skills/kit-gh-pages/) | One-command GitHub Pages setup, auto-detects Vite / Hugo / VitePress / Jekyll |
| [`kit-gh-stars`](./skills/kit-gh-stars/) | GitHub stars → categorized index site (Chinese categories) with weekly CI sync |
| [`kit-project-hub`](./skills/kit-project-hub/) | Your repos → navigation site, featured section + weekly data sync |
| [`kit-wechat-miniapp-ui-optimizer`](./skills/kit-wechat-miniapp-ui-optimizer/) | Native WeChat mini-program UI audit: WXML/WXSS, pages/components, themes, safe areas, assets, and states |
| [`kit-wechat-minigame-ui-optimizer`](./skills/kit-wechat-minigame-ui-optimizer/) | WeChat minigame Canvas UI audit: HUD, touch hit areas, resolution scaling, sprites, states, and frame-rate clues |
| [`kit-gzh-article-pipeline`](./skills/kit-gzh-article-pipeline/) | Product articles for WeChat: evidence, real screenshots, cover, archive/embedded HTML, and validation; enter only the needed stages |

## Install

```bash
./install.sh                          # Linux / macOS / WSL, Bash 3.2+
./install.sh --agent codex kit-shotframe  # select client and skill
./install.sh --dry-run                # preview without writing
.\install.ps1 -Agent codex           # Windows PowerShell (junctions)
npx skills add holtwood/agent-skills-kit   # or via skills.sh
```

The installer links to all three clients by default. `--list` lists skills. Existing ordinary directories are preserved and reported as conflicts (exit 1).

| Client | Default global directory | Override |
| --- | --- | --- |
| Codex | `${CODEX_HOME:-~/.codex}/skills/` | `CODEX_SKILLS_DIR` |
| Claude Code | `~/.claude/skills/` | `CLAUDE_SKILLS_DIR` |
| opencode | `~/.config/opencode/skills/` | `OPENCODE_SKILLS_DIR` |

You can also copy a complete `skills/<name>/` folder into your client's skill directory. Other skill names are untouched.

Requirements: `kit-capture` needs Git Bash / MSYS2 on Windows; desktop/window/clipboard modes use `powershell.exe` on Windows & WSL; `kit-shotframe` needs Node ≥ 18 + Chromium (reuses installed browsers and caches; does not download a browser); GitHub skills need a logged-in [gh CLI](https://cli.github.com/).

## Usage

Each `SKILL.md` is a concise entry point; adjacent `references/` files provide details on demand. Typical pipeline — capture a page → frame it for the app store:

```bash
bash skills/kit-capture/scripts/capture.sh interact https://example.com --width 390 --height 844 --dsf 2 -o page.png
node skills/kit-shotframe/scripts/frame.js --input page.png --preset device --device iphone \
  --ratio appstore-69 --width 1320 --headline "Big headline" --bleed -o store-01.png
```

## Principles

- **Evidence**: real screenshots and repository data; product claims and experiences need evidence; frames use deterministic rendering
- **Zero-dep first**: system tools only; exceptions bootstrap into a cache dir, never project deps
- **Independent distribution**: scripts do not depend on sibling folders; orchestration skills load external capabilities only when needed
- **Small entry points**: precise discovery, references on demand, and continuous execution within the user’s authorized scope

## Validation

```bash
python3 tools/validate_skills.py       # standard-library metadata, link and index checks
python3 tools/check.py                 # offline syntax, CLI and regression checks; Pillow required
python3 tools/check.py --render        # add real Chromium rendering
```

Local checks and CI share this entry point. Browser fixtures are local; GitHub mutations are tested with offline doubles. Article punctuation is unrestricted by default; use `--text-policy legacy` for the old editorial policy.

## Docs

- [docs/SKILL-TEMPLATE.md](./docs/SKILL-TEMPLATE.md): conventions for adding a skill
- [docs/RECOMMENDED-SKILLS.md](./docs/RECOMMENDED-SKILLS.md): third-party skills worth watching (links only)

## License

[MIT](./LICENSE)
