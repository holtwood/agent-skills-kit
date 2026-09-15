# agent-skills-kit

> Installable Agent Skills covering a developer's full "showcase" pipeline: **Capture → Beautify → Publish → Showcase**.
> Chinese documentation and trigger semantics; compatible with opencode / Claude Code / Codex and other mainstream AI coding tools.
>
> **中文**: [README.md](./README.md)

## Skills

| Skill | What it does | Typical triggers |
| --- | --- | --- |
| [`wsl-capture`](./skills/wsl-capture/) | WSL screenshot toolkit: Windows desktop / specific windows / web pages / clipboard, with multi-backend fallback; auto-downloads chrome-headless-shell when no browser is found; `interact` mode clicks, waits, and captures elements or full pages | "take a screenshot", "capture this page", "screenshot a page after logging in", "grab the image from my clipboard" |
| [`shotframe`](./skills/shotframe/) | Screenshot framing & beautification: Chrome/Safari browser frames, macOS window, iPhone/iPad/MacBook/Galaxy/Flip/Fold device frames; gradient & image backdrops, social + app-store exact canvas ratios, copy layer, bleed & tilt composition, vector PDF | "add a frame", "wrap it in an iPhone bezel", "make an OG image", "make a set of App Store screenshots" |
| [`gh-pages`](./skills/gh-pages/) | One-command GitHub Pages setup with auto-detection for Vite / Hugo / VitePress / Jekyll | "enable Pages for this repo" |
| [`gh-stars`](./skills/gh-stars/) | Turn your GitHub stars into a categorized index site (Chinese categories) with weekly CI sync | "turn my stars into a showcase page" |
| [`project-hub`](./skills/project-hub/) | Generate a navigation site for all your repos, with a featured section and weekly audit | "make a navigation page listing my repos" |

## Highlights

- **Store screenshots end-to-end**: `wsl-capture` grabs real pixels → `shotframe` lands official store slots exactly (`--ratio appstore-69 --width 1320` → 1320×2868), with `--headline`/`--subcopy` copy layer plus `--bleed`/`--tilt` composition — a full set of App Store / Google Play marketing shots
- **Deterministic rendering**: output is 100% real screenshots + CSS layout; no image-generation models — reproducible, auditable, no hallucination
- **Zero-dependency first**: only system tools (Chromium / gh CLI / Python); `interact` is the sole exception (installs puppeteer-core into a cache dir on demand, never into your project)
- **Multi-backend fallback**: automatic backend switching on detection failure (PowerShell interop → WSLg → X11 → bootstrap download), with stable readable error codes for agents
- **Self-contained skills**: each skill is `SKILL.md` + `scripts/` + `references/` — copy the folder and it works

## Installation

### Option 1: install script (recommended)

```bash
git clone https://github.com/holtwood/agent-skills-kit.git ~/agent-skills-kit
cd ~/agent-skills-kit

./install.sh                    # Linux / macOS / WSL — install everything
./install.sh shotframe gh-pages # or pick specific skills
.\install.ps1                   # native Windows PowerShell (junctions, no admin needed)
```

### Option 2: npx skills (skills.sh)

```bash
npx skills add holtwood/agent-skills-kit            # interactive picker
npx skills add holtwood/agent-skills-kit --skill shotframe
```

### Option 3: manual copy

Copy `skills/<name>/` into your project's `.opencode/skills/` or `.claude/skills/` directory.

### Requirements

- **OS**: Linux / macOS / WSL (`wsl-capture` needs WSL + `powershell.exe`)
- **bash ≥ 4.4** (`install.sh`; macOS: install bash via Homebrew), **PowerShell ≥ 5.1** (`install.ps1`)
- **Node ≥ 18** (`shotframe`), **Python 3** (generators), logged-in **[gh CLI](https://cli.github.com/)** (GitHub skills)
- **Chromium** (screenshot skills, auto-detected; on Linux/WSL it can bootstrap-download chrome-headless-shell)

## Quick start

```bash
# ── Capture → frame ─────────────────────────────────────
bash skills/wsl-capture/scripts/capture.sh browser https://example.com -o ~/shots/page.png
node skills/shotframe/scripts/frame.js --input ~/shots/page.png --preset macos --output ~/shots/page-macos.png

# ── App Store shot (exact 1320×2868 + copy + bleed & tilt)
node skills/shotframe/scripts/frame.js --input ~/shots/app.png --preset device --device galaxy \
  --ratio appstore-69 --width 1320 \
  --headline "Big headline" --subcopy "One line of subcopy" --bleed --tilt -2 --shadow lifted \
  --output ~/shots/store-01.png

# ── OG / social image (1.91:1 at width 1200) ────────────
node skills/shotframe/scripts/frame.js --input ~/shots/page.png --preset browser \
  --bg aurora --ratio og --width 1200 --output ~/shots/og.png

# ── Interact-then-capture (wait → click → element shot) ─
bash skills/wsl-capture/scripts/capture.sh interact https://app.example.com \
  --waitfor '#welcome' --click '#login' --selector '#dashboard' -o ~/shots/dash.png

# ── GitHub skills ───────────────────────────────────────
bash skills/gh-stars/scripts/fetch-stars.sh holtwood data/starred_full.json
python3 skills/gh-stars/scripts/gen-index.py data/starred_full.json docs/index.html --title "My stars"
bash skills/project-hub/scripts/fetch-repos.sh holtwood data/repos.json
bash skills/gh-pages/scripts/setup-pages.sh holtwood/agent-skills-kit
```

## Design principles

- **Capture and render decoupled**: grab real pixels first, then dress them up; the two are decoupled via file paths and work independently
- **Deterministic over generative**: no image-generation models; output is 100% real data
- **Zero-dependency first**: prefer system tools; exceptions bootstrap into a cache dir without polluting your project
- **Failures speak plainly**: invalid values fail immediately with the list of legal values (`--list` prints them all); nothing silently falls back
- **Agent-agnostic**: not tied to one tool — use a structured picker UI when available, a numbered list when not

## Docs

- [`docs/SKILL-TEMPLATE.md`](./docs/SKILL-TEMPLATE.md): conventions for adding a new skill
- [`docs/RECOMMENDED-SKILLS.md`](./docs/RECOMMENDED-SKILLS.md): third-party skills worth watching (linked, not vendored)
- `skills/shotframe/references/`: design details and troubleshooting for the framing renderer

## License

[MIT](./LICENSE)
