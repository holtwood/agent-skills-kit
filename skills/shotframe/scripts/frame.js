#!/usr/bin/env node
/**
 * shotframe — 截图套框渲染器（零 npm 依赖）
 *
 * 用法:
 *   node frame.js --input <png> --preset <browser|macos> --output <png> [--title T] [--url U] [--background light|dark] [--padding 56] [--chromium PATH]
 */
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');

// ---------- 参数解析 ----------
function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next !== undefined && !next.startsWith('--')) {
        args[key] = next;
        i++;
      } else {
        args[key] = true;
      }
    }
  }
  return args;
}

// ---------- PNG 尺寸读取（零依赖，解析 IHDR） ----------
function pngSize(buf) {
  if (buf.length < 24 || buf.readUInt32BE(0) !== 0x89504e47) {
    throw new Error('仅支持 PNG 输入（读取尺寸需要 PNG 头）');
  }
  return { w: buf.readUInt32BE(16), h: buf.readUInt32BE(20) };
}

// ---------- Chromium 探测 ----------
function findChromium(forced) {
  if (forced && typeof forced === 'string' && fs.existsSync(forced)) return forced;
  const candidates = [
    process.env.SHOTFRAME_CHROMIUM,
    process.env.CHROME_PATH,
    ...globPlaywrightChromium(),
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/snap/bin/chromium',
  ];
  for (const c of candidates) {
    if (c && fs.existsSync(c)) return c;
  }
  // PATH 里找
  for (const dir of (process.env.PATH || '').split(':')) {
    for (const name of ['chromium', 'chromium-browser', 'google-chrome', 'chrome']) {
      const p = path.join(dir, name);
      if (fs.existsSync(p)) return p;
    }
  }
  return null;
}

function globPlaywrightChromium() {
  const cache = path.join(os.homedir(), '.cache', 'ms-playwright');
  let out = [];
  try {
    for (const ver of fs.readdirSync(cache)) {
      if (!ver.startsWith('chromium-')) continue;
      const exe = path.join(cache, ver, 'chrome-linux64', 'chrome');
      if (fs.existsSync(exe)) out.push(exe);
    }
  } catch (_) { /* cache 不存在时忽略 */ }
  return out;
}

// ---------- HTML 模板 ----------
function esc(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function buildHtml({ imgDataUri, imgW, imgH, preset, title, url, background, pad }) {
  const border = 1;
  const radius = 14;
  const shadowCss = '0 24px 60px -12px rgba(15,23,42,.35), 0 8px 24px -8px rgba(15,23,42,.2)';
  const bg =
    background === 'dark'
      ? 'linear-gradient(135deg,#1e293b 0%,#0f172a 60%,#0b1120 100%)'
      : 'linear-gradient(135deg,#e8edf3 0%,#d4dce6 55%,#c3cdda 100%)';

  let chrome = '';
  if (preset === 'macos') {
    chrome = `
      <div class="titlebar">
        <div class="lights"><span class="light r"></span><span class="light y"></span><span class="light g"></span></div>
        ${title ? `<div class="ttl">${esc(title)}</div>` : ''}
      </div>`;
  } else {
    chrome = `
      <div class="tabbar">
        <div class="tab"><span class="fav"></span><span class="tabname">${title ? esc(title) : ''}</span></div>
        <div style="width:30px"></div>
      </div>
      <div class="addrbar">
        <span class="ctrl"></span><span class="ctrl"></span><span class="ctrl"></span>
        <div class="addr">
          <svg class="lock" viewBox="0 0 24 24" fill="none" stroke="#64748b" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
          <span class="url">${url ? esc(url) : ''}</span>
        </div>
      </div>`;
  }

  const topBarH = preset === 'macos' ? 46 : 80;

  return {
    html: `<!doctype html><html><head><meta charset="utf-8"><style>
      * { margin:0; padding:0; box-sizing:border-box; }
      body {
        background: ${bg};
        width:${imgW + pad * 2}px; height:${imgH + pad * 2 + topBarH}px;
        display:flex; align-items:center; justify-content:center;
        font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','PingFang SC','Microsoft YaHei',sans-serif;
        overflow:hidden;
      }
      .win {
        background:#fff; border-radius:${radius}px; overflow:hidden;
        box-shadow:${shadowCss}; border:${border}px solid rgba(148,163,184,.45);
      }
      .titlebar {
        height:46px; background:#f3f5f8; border-bottom:1px solid #e2e8f0;
        display:flex; align-items:center; padding:0 16px; position:relative;
      }
      .lights { display:flex; gap:8px; }
      .light { width:13px; height:13px; border-radius:50%; }
      .r{background:#ff5f57} .y{background:#febc2e} .g{background:#28c840}
      .ttl { position:absolute; left:0; right:0; text-align:center; font-size:13px; font-weight:500; color:#475569; pointer-events:none; }
      .tabbar {
        height:40px; background:#e8ecf2; display:flex; align-items:flex-end; padding:0 10px; gap:2px;
      }
      .tab {
        height:28px; background:#f6f8fb; border:1px solid #d8dfe8; border-bottom:none;
        border-radius:8px 8px 0 0; display:flex; align-items:center; gap:7px;
        padding:0 14px; font-size:12.5px; color:#334155; max-width:240px;
      }
      .fav { width:14px; height:14px; border-radius:4px; background:linear-gradient(135deg,#f97316,#ea580c); flex-shrink:0; }
      .tabname { white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
      .addrbar {
        height:40px; background:#f6f8fb; border-bottom:1px solid #e2e8f0;
        display:flex; align-items:center; gap:8px; padding:0 12px;
      }
      .ctrl { width:12px; height:12px; border-radius:50%; background:#cbd5e1; flex-shrink:0; }
      .addr {
        flex:1; height:30px; background:#fff; border:1px solid #e2e8f0; border-radius:8px;
        display:flex; align-items:center; gap:8px; padding:0 12px; font-size:12.5px; color:#475569;
      }
      .lock { width:13px; height:13px; flex-shrink:0; }
      .url { white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
      .content { line-height:0; }
      img { display:block; width:100%; height:auto; }
    </style></head><body>
      <div class="win">${chrome}<div class="content"><img src="${imgDataUri}"></div></div>
    </body></html>`,
    cssW: imgW + pad * 2,
    cssH: imgH + pad * 2 + topBarH,
  };
}

// ---------- 主流程 ----------
function main() {
  const args = parseArgs(process.argv.slice(2));

  if (typeof args.input !== 'string' || typeof args.output !== 'string') {
    console.error('用法: node frame.js --input <png> --preset <browser|macos> --output <png> [--title T] [--url U] [--background light|dark]');
    process.exit(2);
  }
  const input = args.input;
  const output = args.output;
  const preset = args.preset || 'browser';
  const title = args.title || '';
  const url = args.url || '';
  const background = args.background || 'light';
  const pad = Number(args.padding) || 56;

  if (!fs.existsSync(input)) {
    console.error(`输入文件不存在: ${input}`);
    process.exit(2);
  }
  if (preset !== 'browser' && preset !== 'macos') {
    console.error(`未知 preset: ${preset}（支持 browser / macos）`);
    process.exit(2);
  }

  const chromium = findChromium(args.chromium);
  if (!chromium) {
    console.error('未找到 Chromium。请安装 chromium 或设置 SHOTFRAME_CHROMIUM 环境变量指向浏览器可执行文件。');
    process.exit(1);
  }

  const buf = fs.readFileSync(input);
  const { w, h } = pngSize(buf);
  const dataUri = `data:image/png;base64,${buf.toString('base64')}`;

  const { html, cssW, cssH } = buildHtml({ imgDataUri: dataUri, imgW: w, imgH: h, preset, title, url, background, pad });

  const tmpHtml = path.join(os.tmpdir(), `shotframe-${Date.now()}.html`);
  fs.writeFileSync(tmpHtml, html);

  fs.mkdirSync(path.dirname(path.resolve(output)), { recursive: true });
  try {
    execFileSync(chromium, [
      '--headless=new',
      '--disable-gpu',
      '--no-sandbox',
      '--hide-scrollbars',
      `--force-device-scale-factor=2`,
      `--window-size=${cssW},${cssH}`,
      `--screenshot=${path.resolve(output)}`,
      `file://${tmpHtml}`,
    ], { stdio: 'ignore', timeout: 60000 });
  } catch (e) {
    console.error('Chromium 截图失败:', e.message);
    process.exit(1);
  } finally {
    fs.rmSync(tmpHtml, { force: true });
  }

  if (!fs.existsSync(output) || !fs.statSync(output).size) {
    console.error('输出文件为空或未生成，渲染失败');
    process.exit(1);
  }
  const outSize = fs.statSync(output).size;
  console.log(`✅ ${preset} 框架完成: ${output} (${Math.round(outSize / 1024)} KB, ${cssW * 2}x${cssH * 2})`);
}

main();
