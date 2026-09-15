# agent-skills-kit

> Installable Agent Skills for a solo developer's showcase pipeline: **capture → polish → publish → present**. Chinese docs; works with opencode / Claude Code / Codex.
>
> **中文**: [README.md](./README.md)

## Skills

| Skill | What it does |
| --- | --- |
| [`kit-capture`](./skills/kit-capture/) | Cross-platform screenshots (Win/macOS/Linux/WSL): desktop / windows / web pages / clipboard with multi-backend fallback; `interact` mode clicks, waits, and captures elements |
| [`kit-shotframe`](./skills/kit-shotframe/) | Screenshot framing: browser / macOS / iPhone / Galaxy frames, exact social & app-store canvases, copy layer, vector PDF |
| [`kit-gh-pages`](./skills/kit-gh-pages/) | One-command GitHub Pages setup, auto-detects Vite / Hugo / VitePress / Jekyll |
| [`kit-gh-stars`](./skills/kit-gh-stars/) | GitHub stars → categorized index site (Chinese categories) with weekly CI sync |
| [`kit-project-hub`](./skills/kit-project-hub/) | Your repos → navigation site, featured section + weekly audit |

## Install

```bash
./install.sh                          # Linux / macOS / WSL (bash ≥ 4.4), installs all
./install.sh kit-shotframe            # or pick specific skills
.\install.ps1                         # native Windows PowerShell (junctions)
npx skills add holtwood/agent-skills-kit   # or via skills.sh
```

Or manually copy `skills/<name>/` into `.opencode/skills/` or `.claude/skills/`.

Requirements: `kit-capture` needs Git Bash / MSYS2 on Windows; desktop/window/clipboard modes use `powershell.exe` on Windows & WSL; `kit-shotframe` needs Node ≥ 18 + Chromium (auto-downloads chrome-headless-shell if missing); GitHub skills need a logged-in [gh CLI](https://cli.github.com/).

## Usage

Each skill's `SKILL.md` is the full doc. Typical pipeline — capture a page → frame it for the app store:

```bash
bash skills/kit-capture/scripts/capture.sh browser https://example.com -o page.png
node skills/kit-shotframe/scripts/frame.js --input page.png --preset device --device galaxy \
  --ratio appstore-69 --width 1320 --headline "Big headline" --bleed -o store-01.png
```

## Principles

- **Deterministic**: output is 100% real screenshots + real data; no image-generation models
- **Zero-dep first**: system tools only; exceptions bootstrap into a cache dir, never project deps
- **Self-contained skills**: each skill is `SKILL.md` + `scripts/` — copy the dir and it works

## Docs

- [docs/SKILL-TEMPLATE.md](./docs/SKILL-TEMPLATE.md): conventions for adding a skill
- [docs/RECOMMENDED-SKILLS.md](./docs/RECOMMENDED-SKILLS.md): third-party skills worth watching (links only)

## License

[MIT](./LICENSE)
