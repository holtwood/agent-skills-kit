# agent-skills-zh · Chinese Community Agent Skills Collection

> Installable Agent Skills for Chinese-speaking developers: **Capture → Beautify → Publish → Showcase**, covering a developer's full "showcase" workflow.
> Compatible with opencode / Claude Code / Codex and other mainstream AI coding tools.
>
> **中文**: [README.md](./README.md)

A curated, fully-Chinese Agent Skills collection with Chinese trigger semantics — documentation, output messages, and examples are all in Chinese, ready to use out of the box.

## Skills

| Skill | Capability | When to use |
| --- | --- | --- |
| [`wsl-capture`](./skills/wsl-capture/) | Screenshots in WSL | "take a screenshot / capture a web page / capture a window in WSL" |
| [`shotframe`](./skills/shotframe/) | Screenshot framing (browser / macOS / device) | "add a frame to this screenshot", "wrap it in an iPhone / MacBook bezel" |
| [`gh-pages`](./skills/gh-pages/) | GitHub Pages setup (multi-framework detection) | "enable GitHub Pages for this repo" |
| [`gh-stars`](./skills/gh-stars/) | Star collection index site (Chinese categories + CI sync) | "turn my stars into a showcase page" |
| [`project-hub`](./skills/project-hub/) | Repo navigation site (featured section + weekly audit) | "make a navigation page listing all my repos" |

## Design principles

- **Capture and render decoupled**: screenshot skills grab real pixels first, then dress them up; the two are decoupled via file paths and work independently
- **Multi-backend fallback**: every capability has several backends (PowerShell interop → WSLg → X11); automatic fallback when environment detection fails
- **Deterministic over generative**: no image-generation models are called; output is 100% from real data
- **Zero-dependency first**: scripts only rely on system tools already present (Chromium / gh CLI / Python stdlib)
- **Self-contained skills**: each skill is fully self-contained (`SKILL.md` + `scripts/`), copy the directory into any project to use

## Installation

```bash
git clone https://github.com/holtwood/agent-skills-zh.git ~/agent-skills-zh
cd ~/agent-skills-zh

# Install all skills locally (opencode + Claude Code)
./install.sh

# Or install selected skills
./install.sh shotframe gh-pages
```

> Want it for a specific project? Just copy the `skills/<name>/` directory into your project's `.opencode/skills/` or `.claude/skills/`.

### Requirements

- **OS**: Linux / WSL (`wsl-capture` needs WSL + `powershell.exe`; macOS partially works with `coreutils`)
- **bash ≥ 4.3** (`install.sh` uses `mapfile -d`; macOS users: install bash via Homebrew)
- **Dependencies as needed**: screenshot skills need a system Chromium; GitHub skills need [gh CLI](https://cli.github.com/) logged in; generator skills need Python 3

## Quick start

```bash
# Capture → frame in one go (window / device)
bash skills/wsl-capture/scripts/capture.sh browser https://example.com -o ~/shots/page.png
node skills/shotframe/scripts/frame.js --input ~/shots/page.png --preset macos --output ~/shots/page-macos.png
node skills/shotframe/scripts/frame.js --input ~/shots/app.png --preset device --device iphone --output ~/shots/app-iphone.png

# Star collection site (fetch → generate index → weekly CI sync)
bash skills/gh-stars/scripts/fetch-stars.sh holtwood data/starred_full.json
python3 skills/gh-stars/scripts/gen-index.py data/starred_full.json docs/index.html --title "My stars"
bash skills/gh-stars/scripts/setup-ci.sh .

# Repo navigation site (fetch → generate → weekly audit)
bash skills/project-hub/scripts/fetch-repos.sh holtwood data/repos.json
python3 skills/project-hub/scripts/gen-hub.py data/repos.json docs/index.html --title "My projects" --featured my-app
bash skills/project-hub/scripts/setup-ci.sh .

# Or deploy as GitHub Pages (auto-detects Vite / Hugo / VitePress / Jekyll)
bash skills/gh-pages/scripts/setup-pages.sh holtwood/agent-skills-zh
```

## Adding a new skill

Want to add a skill to the collection? Read the authoring conventions in [`docs/SKILL-TEMPLATE.md`](./docs/SKILL-TEMPLATE.md) first to keep the style consistent.

## Roadmap

- [x] Screenshot chain: `wsl-capture` + `shotframe` (browser / macOS frames)
- [x] Device frames: iPhone / iPad / MacBook
- [x] `gh-pages`: multi-framework detection (Vite / Hugo / VitePress / Jekyll)
- [x] `gh-stars`: Chinese category mapping + CI auto-sync
- [x] `project-hub`: featured section + group navigation + weekly audit
- [x] Bilingual README

## License

[MIT](./LICENSE)
