#!/usr/bin/env node
/**
 * shotframe — 截图套框渲染器（零 npm 依赖）
 *
 * 用法:
 *   node frame.js --input <png> --preset <browser|macos|device> --output <png> \
 *     [--device iphone|ipad|macbook] [--title T] [--url U] \
 *     [--theme auto|light|dark] [--trim] [--padding 56] [--chromium PATH] \
 *     [--bg aurora|solid:#0f172a|linear:#a8edea,#fed6e3|none] [--angle 135] \
 *     [--ratio twitter|1.91:1] [--width 1200] [--inset 12] [--radius 16] \
 *     [--transparent] [--all] [--list] [--json]
 *
 * --theme auto : 按截图亮度自动选择 chrome(标签页/标题栏)与背景的深浅配色
 * --trim       : 裁掉输入四周与角落同色的均匀空白边(桌面背景/视口留白)后再套框
 * --bg         : 背景，命名渐变预设（随 --theme 取深浅变体）/ 纯色 / 自定义渐变 / 透明
 * --ratio      : 社媒画布比例，只扩画布不裁剪（多出来的空间由背景填充）
 * --width      : 目标输出宽度，只缩小不放大（通过设备像素比实现，不重采样）
 * --inset      : 采样截图边缘颜色，在卡片内侧加一圈同色衬边
 * --all        : 对每个背景预设各出一张（--output 作为基名，如 out.png → out-aurora.png）
 * --list       : 列出所有可用取值后退出（agent 用来发现能力）
 * --json       : 输出机读回执（stdout），人类可读日志走 stderr
 */
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const zlib = require('zlib');
const { execFileSync } = require('child_process');
const { pathToFileURL } = require('url');

// ---------- 参数解析 ----------
const VALUE_FLAGS = new Set([
  'input', 'output', 'preset', 'device', 'title', 'url', 'theme', 'background',
  'padding', 'chromium', 'bg', 'angle', 'ratio', 'width', 'inset', 'radius',
]);
function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (VALUE_FLAGS.has(key) && next !== undefined) {
        args[key] = next;
        i++;
      } else if (next !== undefined && !next.startsWith('--')) {
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

// ---------- PNG 解码（主题检测 / --trim 用，仅支持 8-bit 非隔行） ----------
function decodePng(buf) {
  try {
    if (buf.length < 57 || buf.readUInt32BE(0) !== 0x89504e47) return null;
    let pos = 8;
    let width = 0, height = 0, bitDepth = 0, colorType = 0, interlace = 1;
    let palette = null;
    const idat = [];
    while (pos + 8 <= buf.length) {
      const len = buf.readUInt32BE(pos);
      const type = buf.toString('ascii', pos + 4, pos + 8);
      const data = buf.subarray(pos + 8, pos + 8 + len);
      if (type === 'IHDR') {
        width = data.readUInt32BE(0);
        height = data.readUInt32BE(4);
        bitDepth = data[8];
        colorType = data[9];
        interlace = data[12];
      } else if (type === 'PLTE') {
        palette = data;
      } else if (type === 'IDAT') {
        idat.push(data);
      } else if (type === 'IEND') {
        break;
      }
      pos += 12 + len;
    }
    if (!width || !height || bitDepth !== 8 || interlace !== 0) return null;
    const channels = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[colorType];
    if (!channels || (colorType === 3 && !palette)) return null;
    const raw = zlib.inflateSync(Buffer.concat(idat));
    const stride = width * channels;
    const rows = Buffer.alloc(height * stride);
    let prev = Buffer.alloc(stride);
    for (let y = 0; y < height; y++) {
      const f = raw[y * (stride + 1)];
      const src = y * (stride + 1) + 1;
      const row = rows.subarray(y * stride, (y + 1) * stride);
      for (let i = 0; i < stride; i++) {
        const a = i >= channels ? row[i - channels] : 0;
        const b = prev[i];
        const c = i >= channels ? prev[i - channels] : 0;
        let v = raw[src + i];
        if (f === 1) v = (v + a) & 0xff;
        else if (f === 2) v = (v + b) & 0xff;
        else if (f === 3) v = (v + ((a + b) >> 1)) & 0xff;
        else if (f === 4) {
          const p = a + b - c;
          const pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
          v = (v + (pa <= pb && pa <= pc ? a : pb <= pc ? b : c)) & 0xff;
        }
        row[i] = v;
      }
      prev = row;
    }
    return {
      width, height, channels, rows, palette, colorType,
      getPixel(x, y) {
        const i = y * stride + x * channels;
        switch (channels) {
          case 1:
            if (palette) { const p = rows[i] * 3; return [palette[p], palette[p + 1], palette[p + 2]]; }
            return [rows[i], rows[i], rows[i]];
          case 2: return [rows[i], rows[i], rows[i]]; // 灰度+alpha：亮度取灰度，跳过 alpha 字节
          case 3: return [rows[i], rows[i + 1], rows[i + 2]];
          default: return [rows[i], rows[i + 1], rows[i + 2]];
        }
      },
    };
  } catch (_) {
    return null;
  }
}

// ---------- PNG 编码（--trim 裁剪后重封装） ----------
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function pngChunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crc]);
}

function encodePng(width, height, channels, pixels) {
  const stride = width * channels;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0; // filter: None
    pixels.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = channels === 4 ? 6 : 2; // RGBA / RGB
  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  return Buffer.concat([
    sig,
    pngChunk('IHDR', ihdr),
    pngChunk('IDAT', zlib.deflateSync(raw, { level: 6 })),
    pngChunk('IEND', Buffer.alloc(0)),
  ]);
}

function cropPng(decoded, box) {
  const { width: w, channels, rows, palette } = decoded;
  const { left, top, width: cw, height: ch } = box;
  const outCh = channels === 4 || channels === 2 ? 4 : 3; // 保留 alpha（含灰度+alpha），其余统一 RGB
  const out = Buffer.alloc(cw * ch * outCh);
  for (let y = 0; y < ch; y++) {
    const srcRow = (top + y) * w * channels;
    const dstRow = y * cw * outCh;
    for (let x = 0; x < cw; x++) {
      const si = srcRow + (left + x) * channels;
      const di = dstRow + x * outCh;
      let r, g, b, a = 255;
      if (channels === 1) {
        const v = rows[si];
        if (palette) { r = palette[v * 3]; g = palette[v * 3 + 1]; b = palette[v * 3 + 2]; }
        else { r = g = b = v; }
      } else if (channels === 2) {
        r = g = b = rows[si]; a = rows[si + 1];
      } else {
        r = rows[si]; g = rows[si + 1]; b = rows[si + 2];
        if (channels === 4) a = rows[si + 3];
      }
      out[di] = r; out[di + 1] = g; out[di + 2] = b;
      if (outCh === 4) out[di + 3] = a;
    }
  }
  return encodePng(cw, ch, outCh, out);
}

// ---------- 主题自动检测 ----------
// box 可选：传入 --trim 的裁剪区时，只在真实 UI 区域上采样，
// 避免四周空白边抬高/压低均值导致主题误判。
function detectTheme(decoded, box) {
  const x0 = box ? box.left : 0;
  const y0 = box ? box.top : 0;
  const x1 = box ? box.left + box.width : decoded.width;
  const y1 = box ? box.top + box.height : decoded.height;
  const w = x1 - x0, h = y1 - y0;
  const stepX = Math.max(1, Math.floor(w / 48));
  const stepY = Math.max(1, Math.floor(h / 48));
  let sum = 0, n = 0;
  for (let y = y0 + Math.floor(h * 0.03); y < y1; y += stepY) {
    for (let x = x0 + Math.floor(w * 0.03); x < x1; x += stepX) {
      const p = decoded.getPixel(x, y);
      sum += 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2];
      n++;
    }
  }
  return n && sum / n < 128 ? 'dark' : 'light';
}

// ---------- 均匀色边检测（--trim） ----------
// 容差收紧到每通道 ~7：纯色空白边(PNG 无噪点)可精确裁除，
// 而渐变背景/投影会超出容差而提前停止，避免裁进真实内容。
function computeTrimBox(decoded) {
  const { width: w, height: h, getPixel } = decoded;
  const corners = [getPixel(0, 0), getPixel(w - 1, 0), getPixel(0, h - 1), getPixel(w - 1, h - 1)];
  const ref = [0, 1, 2].map((i) => corners.reduce((s, c) => s + c[i], 0) / 4);
  const near = (p) => Math.abs(p[0] - ref[0]) + Math.abs(p[1] - ref[1]) + Math.abs(p[2] - ref[2]) <= 21;
  const rowNear = (y) => {
    for (let x = 0; x < w; x += 2) if (!near(getPixel(x, y))) return false;
    return true;
  };
  const colNear = (x) => {
    for (let y = 0; y < h; y += 2) if (!near(getPixel(x, y))) return false;
    return true;
  };
  const maxY = Math.floor(h * 0.2), maxX = Math.floor(w * 0.2);
  let top = 0;
  while (top < maxY && rowNear(top)) top++;
  let bottom = h;
  while (h - bottom < maxY && rowNear(bottom - 1)) bottom--;
  let left = 0;
  while (left < maxX && colNear(left)) left++;
  let right = w;
  while (w - right < maxX && colNear(right - 1)) right--;
  const cw = right - left, chh = bottom - top;
  if (cw < 32 || chh < 32 || (cw === w && chh === h)) return null;
  return { left, top, width: cw, height: chh };
}

// ---------- Chromium 探测 ----------
const IS_WIN = process.platform === 'win32';
const IS_MAC = process.platform === 'darwin';

// 各平台常见的 Chromium 安装位置
function platformChromiumPaths() {
  if (IS_MAC) {
    return [
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      '/Applications/Chromium.app/Contents/MacOS/Chromium',
      '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
      '/opt/homebrew/bin/chromium',
      '/usr/local/bin/chromium',
    ];
  }
  if (IS_WIN) {
    const roots = [
      process.env.PROGRAMFILES,
      process.env['PROGRAMFILES(X86)'],
      process.env.LOCALAPPDATA,
    ].filter(Boolean);
    const rel = [
      path.join('Google', 'Chrome', 'Application', 'chrome.exe'),
      path.join('Chromium', 'Application', 'chrome.exe'),
      path.join('Microsoft', 'Edge', 'Application', 'msedge.exe'),
    ];
    const out = [];
    for (const root of roots) for (const r of rel) out.push(path.join(root, r));
    return out;
  }
  return [
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/snap/bin/chromium',
  ];
}

// PATH 里按可执行文件名查找（Windows 需带 .exe 后缀）
function chromiumCommandNames() {
  return IS_WIN
    ? ['chrome.exe', 'chromium.exe', 'msedge.exe']
    : ['chromium', 'chromium-browser', 'google-chrome', 'google-chrome-stable', 'chrome'];
}

function findChromium(forced) {
  if (forced && typeof forced === 'string' && fs.existsSync(forced)) return forced;
  const candidates = [
    process.env.SHOTFRAME_CHROMIUM,
    process.env.CHROME_PATH,
    ...globPlaywrightChromium(),
    ...platformChromiumPaths(),
  ];
  for (const c of candidates) {
    if (c && fs.existsSync(c)) return c;
  }
  // PATH 里找（用 path.delimiter：Windows 为 ';'，其余为 ':'）
  for (const dir of (process.env.PATH || '').split(path.delimiter)) {
    if (!dir) continue;
    for (const name of chromiumCommandNames()) {
      const p = path.join(dir, name);
      if (fs.existsSync(p)) return p;
    }
  }
  return null;
}

// Playwright 下载的 Chromium 缓存目录（各平台不同）
function playwrightCacheDirs() {
  if (IS_WIN) {
    const base = process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local');
    return [path.join(base, 'ms-playwright')];
  }
  if (IS_MAC) {
    return [path.join(os.homedir(), 'Library', 'Caches', 'ms-playwright')];
  }
  const xdg = process.env.XDG_CACHE_HOME;
  const base = xdg && path.isAbsolute(xdg) ? xdg : path.join(os.homedir(), '.cache');
  return [path.join(base, 'ms-playwright')];
}

// 缓存内可执行文件的相对布局（各平台不同）
function playwrightLayouts() {
  if (IS_WIN) {
    return [
      { dir: 'chrome-win64', exe: 'chrome.exe' },
      { dir: 'chrome-win', exe: 'chrome.exe' },
    ];
  }
  if (IS_MAC) {
    return [{ dir: 'chrome-mac', exe: path.join('Chromium.app', 'Contents', 'MacOS', 'Chromium') }];
  }
  return [
    { dir: 'chrome-linux64', exe: 'chrome' },
    { dir: 'chrome-linux', exe: 'chrome' },
  ];
}

function globPlaywrightChromium() {
  const layouts = playwrightLayouts();
  const out = [];
  for (const cache of playwrightCacheDirs()) {
    let versions;
    try {
      versions = fs.readdirSync(cache);
    } catch (_) {
      continue; // cache 不存在时忽略
    }
    for (const ver of versions) {
      if (!ver.startsWith('chromium-')) continue;
      for (const { dir, exe } of layouts) {
        const p = path.join(cache, ver, dir, exe);
        if (fs.existsSync(p)) { out.push(p); break; }
      }
    }
  }
  return out;
}

// ---------- 设备框配置（逻辑 CSS 像素） ----------
const DEVICES = {
  iphone:  { screenW: 390, bezel: 18, radius: 56, screenRadius: 44, notch: 'island', home: true,  buttons: true },
  ipad:    { screenW: 760, bezel: 30, radius: 38, screenRadius: 22, notch: 'dot',    home: true,  buttons: false },
  macbook: { screenW: 1180, bezel: 22, radius: 18, screenRadius: 8, notch: true, chin: 34, buttons: false },
};

// ---------- 主题配色（chrome = 标签页/标题栏/地址栏 + 外层背景） ----------
const THEMES = {
  light: {
    bg: 'linear-gradient(135deg,#e8edf3 0%,#d4dce6 55%,#c3cdda 100%)',
    winBg: '#fff',
    winBorder: 'rgba(148,163,184,.45)',
    shadow: '0 24px 60px -12px rgba(15,23,42,.35), 0 8px 24px -8px rgba(15,23,42,.2)',
    titlebarBg: '#f3f5f8', titlebarBorder: '#e2e8f0', titleText: '#475569',
    tabbarBg: '#e8ecf2', tabBg: '#f6f8fb', tabBorder: '#d8dfe8', tabText: '#334155',
    addrbarBg: '#f6f8fb', addrbarBorder: '#e2e8f0', ctrlBg: '#cbd5e1',
    addrBg: '#fff', addrBorder: '#e2e8f0', addrText: '#475569',
    lockStroke: '#64748b',
  },
  dark: {
    bg: 'linear-gradient(135deg,#2a3547 0%,#1a2434 55%,#121b2c 100%)',
    winBg: '#1b212c',
    winBorder: 'rgba(148,163,184,.5)',
    shadow: '0 32px 80px -16px rgba(2,6,23,.75), 0 8px 24px -8px rgba(2,6,23,.5)',
    titlebarBg: '#232a37', titlebarBorder: '#161c26', titleText: '#94a3b8',
    tabbarBg: '#1a212d', tabBg: '#242c3a', tabBorder: '#313b4d', tabText: '#cbd5e1',
    addrbarBg: '#242c3a', addrbarBorder: '#161c26', ctrlBg: '#3d4759',
    addrBg: '#151b26', addrBorder: '#313b4d', addrText: '#94a3b8',
    lockStroke: '#7c8aa0',
  },
};

// ---------- 背景渐变预设（每组含 light / dark 两个变体，跟随 --theme 选择） ----------
// 命名预设负责「一眼好看」，--bg solid:/linear: 负责精确控制，两者互补。
const GRADIENTS = {
  aurora:   { light: 'linear-gradient(ANGLEdeg,#d9f2ff 0%,#f0e6ff 50%,#ffe8f2 100%)', dark: 'linear-gradient(ANGLEdeg,#0f2b46 0%,#1a2242 50%,#2a1b3d 100%)' },
  sky:      { light: 'linear-gradient(ANGLEdeg,#cfe8ff 0%,#eaf4ff 100%)',            dark: 'linear-gradient(ANGLEdeg,#0b2436 0%,#123049 100%)' },
  sunset:   { light: 'linear-gradient(ANGLEdeg,#ffe6c7 0%,#ffd2d2 100%)',            dark: 'linear-gradient(ANGLEdeg,#3a1d2b 0%,#4a2532 100%)' },
  ocean:    { light: 'linear-gradient(ANGLEdeg,#cdeef4 0%,#d7e7f7 100%)',            dark: 'linear-gradient(ANGLEdeg,#06283d 0%,#0b3a52 100%)' },
  lavender: { light: 'linear-gradient(ANGLEdeg,#e7e0ff 0%,#f4edff 100%)',            dark: 'linear-gradient(ANGLEdeg,#211a3d 0%,#2c2350 100%)' },
  forest:   { light: 'linear-gradient(ANGLEdeg,#d8efe0 0%,#eaf6ec 100%)',            dark: 'linear-gradient(ANGLEdeg,#0e2a20 0%,#16422f 100%)' },
  candy:    { light: 'linear-gradient(ANGLEdeg,#ffd9e8 0%,#e3ddff 100%)',            dark: 'linear-gradient(ANGLEdeg,#3a1430 0%,#2a1a45 100%)' },
  slate:    { light: 'linear-gradient(ANGLEdeg,#e2e8f0 0%,#cbd5e1 100%)',            dark: 'linear-gradient(ANGLEdeg,#1e293b 0%,#0f172a 100%)' },
  mono:     { light: 'linear-gradient(ANGLEdeg,#f4f6f9 0%,#e3e8ee 100%)',            dark: 'linear-gradient(ANGLEdeg,#20252f 0%,#14181f 100%)' },
};

// ---------- 社媒画布比例 ----------
const RATIOS = {
  linkedin: [1.91, 1], og: [1.91, 1], facebook: [1.91, 1],
  'linkedin-square': [1, 1], instagram: [1, 1],
  'linkedin-portrait': [4, 5], 'instagram-portrait': [4, 5],
  'linkedin-banner': [4, 1],
  twitter: [16, 9], x: [16, 9], youtube: [16, 9],
  story: [9, 16],
};

const HEX_RE = /^#[0-9a-fA-F]{3,8}$/;

// 解析 --ratio：命名比例，或任意 W:H / WxH
function parseRatio(spec) {
  const key = String(spec || '').trim().toLowerCase();
  if (!key) return null;
  if (RATIOS[key]) return RATIOS[key];
  const m = key.match(/^(\d+(?:\.\d+)?)\s*[:x/\u00d7]\s*(\d+(?:\.\d+)?)$/);
  if (!m) return null;
  const w = Number(m[1]), h = Number(m[2]);
  return (w > 0 && h > 0) ? [w, h] : null;
}

// 比例只扩画布、不裁剪：内容居中，多出来的空间由背景填充
function fitToRatio(w, h, ratio) {
  if (!ratio) return { width: w, height: h };
  const r = ratio[0] / ratio[1];
  if (w / h < r) return { width: Math.round(h * r), height: h };
  if (w / h > r) return { width: w, height: Math.round(w / r) };
  return { width: w, height: h };
}

// 解析 --bg：命名渐变 / solid:#hex / linear:#a,#b / none / light|dark（旧参数） / 空=跟随主题
// 返回 null 表示取值非法（由调用方报错）
function resolveBackground(spec, theme, angle) {
  const deg = Number.isFinite(angle) ? angle : 135;
  const raw = String(spec == null ? '' : spec).trim();
  // 内置主题背景也走 --angle，否则「--angle 单独用没有任何效果」会是个静默空操作
  const themeBg = (t) => THEMES[t].bg.replace(/135deg/, `${deg}deg`);
  if (!raw) return { css: themeBg(theme), transparent: false, label: `theme:${theme}`, angle: deg };
  if (raw === 'none' || raw === 'transparent') return { css: 'transparent', transparent: true, label: 'none' };
  if (raw === 'light' || raw === 'dark') return { css: themeBg(raw), transparent: false, label: `theme:${raw}`, angle: deg };
  if (raw.startsWith('solid:')) {
    const c = raw.slice(6).trim();
    return HEX_RE.test(c) ? { css: c, transparent: false, label: raw } : null;
  }
  if (raw.startsWith('linear:')) {
    const stops = raw.slice(7).split(',').map((s) => s.trim()).filter(Boolean);
    if (stops.length < 2 || !stops.every((s) => HEX_RE.test(s))) return null;
    return {
      css: `linear-gradient(${deg}deg,${stops.join(',')})`,
      transparent: false,
      angle: deg,
      label: raw,
    };
  }
  if (GRADIENTS[raw]) {
    return {
      css: GRADIENTS[raw][theme].replace('ANGLE', String(deg)),
      transparent: false,
      angle: deg,
      label: raw,
    };
  }
  return null;
}

// 采样截图四周最常见的颜色（--inset 用）；量化到 16 阶以容忍噪点
function edgeColor(decoded) {
  if (!decoded) return null;
  const w = decoded.width, h = decoded.height;
  if (!w || !h) return null;
  const counts = new Map();
  const bump = (x, y) => {
    const [r, g, b] = decoded.getPixel(x, y);
    const k = `${r >> 4}:${g >> 4}:${b >> 4}`;
    const cur = counts.get(k) || { n: 0, r: 0, g: 0, b: 0 };
    cur.n++; cur.r += r; cur.g += g; cur.b += b;
    counts.set(k, cur);
  };
  const stepX = Math.max(1, Math.floor(w / 64));
  const stepY = Math.max(1, Math.floor(h / 64));
  for (let x = 0; x < w; x += stepX) { bump(x, 0); bump(x, h - 1); }
  for (let y = 0; y < h; y += stepY) { bump(0, y); bump(w - 1, y); }
  let best = null;
  for (const v of counts.values()) if (!best || v.n > best.n) best = v;
  if (!best) return null;
  return `rgb(${Math.round(best.r / best.n)},${Math.round(best.g / best.n)},${Math.round(best.b / best.n)})`;
}

// ---------- HTML 模板 ----------
function esc(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function buildHtml({ imgDataUri, imgW, imgH, preset, device, title, url, theme, bgCss, canvasW, canvasH, radius, inset, insetColor }) {
  const T = THEMES[theme] || THEMES.light;
  const bg = bgCss || T.bg;
  const cardRadius = Number.isFinite(radius) ? radius : 14;
  // --inset：在卡片内侧衬一圈「截图边缘色」，截图等比缩小填进去
  const matteCss = inset > 0 ? `padding:${inset}px;background:${insetColor || '#fff'};` : '';

  let inner = '';
  // contentW/H = 被套框元素的尺寸（不含四周留白）；画布尺寸由调用方按留白与比例算出
  let contentW = 0;
  let contentH = 0;
  let deviceCss = '';

  if (preset === 'device') {
    const d = DEVICES[device];
    const screenW = d.screenW;
    const b = d.bezel;
    const innerW = Math.max(1, screenW - inset * 2);
    const innerH = imgW > 0 ? Math.round((innerW * imgH) / imgW) : 0;
    const screenH = innerH + inset * 2;

    if (device === 'macbook') {
      contentW = screenW + b * 2;
      contentH = b + screenH + b + d.chin;
      inner = `<div class="mac" style="--r:${d.radius}px;--sr:${d.screenRadius}px;--b:${b}px;--c:${d.chin}px;--iw:${innerW}px;--ih:${innerH}px;width:${screenW + b * 2}px">
  <div class="lid"><div class="screen" style="${matteCss}"><img src="${imgDataUri}"><div class="notch"></div></div></div>
  <div class="chin"><div class="logo"></div></div>
</div>`;
    } else {
      contentW = screenW + b * 2;
      contentH = screenH + b * 2;
      const topAccent =
        d.notch === 'island' ? '<div class="island"></div>'
        : d.notch === 'dot' ? '<div class="camdot"></div>' : '';
      const btns = d.buttons ? '<div class="btn lt"></div><div class="btn lm"></div><div class="btn rt"></div>' : '';
      const home = d.home ? '<div class="homeind"></div>' : '';
      inner = `<div class="device" style="--r:${d.radius}px;--sr:${d.screenRadius}px;--b:${b}px;--iw:${innerW}px;--ih:${innerH}px;width:${screenW + b * 2}px">
  <div class="bezel">
    <div class="screen" style="${matteCss}"><img src="${imgDataUri}"></div>
    ${topAccent}${home}
  </div>
  ${btns}
</div>`;
    }

    deviceCss = `
      .device, .mac { position:relative; flex:none; }
      .bezel { background:#0b0f14; border-radius:var(--r); padding:var(--b); border:1px solid #1f2937; box-shadow:${T.shadow}; position:relative; }
      .device .screen, .lid .screen { border-radius:var(--sr); overflow:hidden; line-height:0; background:#000; }
      .device img, .mac img { display:block; width:var(--iw); height:var(--ih); }
      .island { position:absolute; top:calc(var(--b) + 8px); left:50%; transform:translateX(-50%); width:126px; height:34px; background:#000; border-radius:999px; box-shadow:inset 0 0 0 1px #1f2937; }
      .camdot { position:absolute; top:calc((var(--b) - 10px) / 2); left:50%; transform:translateX(-50%); width:10px; height:10px; border-radius:50%; background:#475569; box-shadow:0 0 0 3px #0b0f14; }
      .homeind { position:absolute; bottom:calc(var(--b) + 7px); left:50%; transform:translateX(-50%); width:132px; height:5px; border-radius:999px; background:#27272a; }
      .btn { position:absolute; background:#232a33; border-radius:4px; }
      .btn.lt { left:-4px; top:16%; width:4px; height:9%; min-height:22px; }
      .btn.lm { left:-4px; top:27%; width:4px; height:12%; min-height:30px; }
      .btn.rt { right:-4px; top:21%; width:4px; height:17%; min-height:44px; }
      .lid { background:linear-gradient(180deg,#2b2e36,#23262d); border-radius:var(--r); padding:var(--b); box-shadow:${T.shadow}; border:1px solid #1a1d23; border-bottom:none; }
      .mac .screen { position:relative; }
      .notch { position:absolute; top:0; left:50%; transform:translateX(-50%); width:150px; height:22px; background:#000; border-radius:0 0 12px 12px; }
      .chin { height:var(--c); background:linear-gradient(180deg,#3a3e47,#2b2e36); border-radius:0 0 var(--r) var(--r); display:flex; align-items:center; justify-content:center; border:1px solid #1a1d23; border-top:none; }
      .logo { width:16px; height:16px; border-radius:50%; background:#8a8f9a; }`;
  } else {
    // 窗口预设：macOS / 浏览器
    const innerW = Math.max(1, imgW - inset * 2);
    const innerH = imgW > 0 ? Math.round((innerW * imgH) / imgW) : 0;
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
            <svg class="lock" viewBox="0 0 24 24" fill="none" stroke="${T.lockStroke}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
            <span class="url">${url ? esc(url) : ''}</span>
          </div>
        </div>`;
    }
    const topBarH = preset === 'macos' ? 46 : 80;
    contentW = imgW;
    contentH = innerH + inset * 2 + topBarH;
    inner = `<div class="win">${chrome}<div class="content" style="${matteCss}"><img src="${imgDataUri}" style="width:${innerW}px;height:${innerH}px"></div></div>`;

    deviceCss = `
      .win {
        background:${T.winBg}; border-radius:${cardRadius}px; overflow:hidden;
        box-shadow:${T.shadow}; border:1px solid ${T.winBorder};
      }
      .titlebar {
        height:46px; background:${T.titlebarBg}; border-bottom:1px solid ${T.titlebarBorder};
        display:flex; align-items:center; padding:0 16px; position:relative;
      }
      .lights { display:flex; gap:8px; }
      .light { width:13px; height:13px; border-radius:50%; }
      .r{background:#ff5f57} .y{background:#febc2e} .g{background:#28c840}
      .ttl { position:absolute; left:0; right:0; text-align:center; font-size:13px; font-weight:500; color:${T.titleText}; pointer-events:none; }
      .tabbar {
        height:40px; background:${T.tabbarBg}; display:flex; align-items:flex-end; padding:0 10px; gap:2px;
      }
      .tab {
        height:28px; background:${T.tabBg}; border:1px solid ${T.tabBorder}; border-bottom:none;
        border-radius:8px 8px 0 0; display:flex; align-items:center; gap:7px;
        padding:0 14px; font-size:12.5px; color:${T.tabText}; max-width:240px;
      }
      .fav { width:14px; height:14px; border-radius:4px; background:linear-gradient(135deg,#f97316,#ea580c); flex-shrink:0; }
      .tabname { white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
      .addrbar {
        height:40px; background:${T.addrbarBg}; border-bottom:1px solid ${T.addrbarBorder};
        display:flex; align-items:center; gap:8px; padding:0 12px;
      }
      .ctrl { width:12px; height:12px; border-radius:50%; background:${T.ctrlBg}; flex-shrink:0; }
      .addr {
        flex:1; height:30px; background:${T.addrBg}; border:1px solid ${T.addrBorder}; border-radius:8px;
        display:flex; align-items:center; gap:8px; padding:0 12px; font-size:12.5px; color:${T.addrText};
      }
      .lock { width:13px; height:13px; flex-shrink:0; }
      .url { white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
      .content { line-height:0; }
      .content img { display:block; }`;
  }

  return {
    html: `<!doctype html><html><head><meta charset="utf-8"><style>
      * { margin:0; padding:0; box-sizing:border-box; }
      html, body { background: ${bg}; }
      body {
        width:${canvasW}px; height:${canvasH}px;
        display:flex; align-items:center; justify-content:center;
        font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','PingFang SC','Microsoft YaHei',sans-serif;
        overflow:hidden;
      }
      ${deviceCss}
    </style></head><body>
      ${inner}
    </body></html>`,
    contentW,
    contentH,
  };
}

// 资源上限：超过就提前失败，而不是让 Chromium 卡到超时再报语焉不详的错
const MAX_CANVAS_SIDE = 16000;        // CSS px，单边上限
const MAX_OUTPUT_PIXELS = 120e6;      // 输出像素总量上限（≈120MP）

// ---------- 渲染 ----------
// 用系统 Chromium 无头渲染 HTML 到 PNG；尺寸不符时按差值校正窗口尺寸重试一次
// （防御无头窗口被显示环境钳制）。小数 device-scale-factor 会有 1px 舍入，故容差为 ±1。
function renderFrame({ chromium, html, output, cssW, cssH, scale, transparent }) {
  const tmpHtml = path.join(os.tmpdir(), `shotframe-${process.pid}-${crypto.randomBytes(6).toString('hex')}.html`);
  fs.writeFileSync(tmpHtml, html, { flag: 'wx', mode: 0o600 });
  fs.mkdirSync(path.dirname(path.resolve(output)), { recursive: true });

  const expectedW = Math.round(cssW * scale);
  const expectedH = Math.round(cssH * scale);
  const renderOnce = (winW, winH) => {
    const flags = [
      '--headless=new',
      '--disable-gpu',
      '--no-sandbox',
      '--hide-scrollbars',
      `--force-device-scale-factor=${scale}`,
      `--window-size=${winW},${winH}`,
      `--screenshot=${path.resolve(output)}`,
    ];
    // 透明背景：Chromium 默认铺白底，需显式要求 0 alpha 的默认底色
    if (transparent) flags.push('--default-background-color=00000000');
    flags.push(pathToFileURL(tmpHtml).href);
    execFileSync(chromium, flags, { stdio: 'ignore', timeout: 60000 });
  };

  let winW = cssW, winH = cssH;
  let verified = false;
  let actual = null;
  try {
    for (let attempt = 0; attempt < 2; attempt++) {
      renderOnce(winW, winH);
      try {
        const out = pngSize(fs.readFileSync(path.resolve(output)));
        actual = { w: out.w, h: out.h };
      } catch (_) {
        actual = null;
        break;
      }
      if (Math.abs(actual.w - expectedW) <= 1 && Math.abs(actual.h - expectedH) <= 1) {
        verified = true;
        break;
      }
      // 按差值校正窗口尺寸后重试（防负值/过小值导致 Chromium 报错）
      winW = Math.max(200, winW + Math.round(cssW - actual.w / scale));
      winH = Math.max(200, winH + Math.round(cssH - actual.h / scale));
    }
  } finally {
    fs.rmSync(tmpHtml, { force: true });
  }
  // 区分三种结果，避免把「根本没产出文件」误报成「尺寸不符」
  const reason = verified ? 'ok' : (actual ? 'size-mismatch' : 'no-output');
  return {
    reason,
    verified,
    expectedW,
    expectedH,
    width: actual ? actual.w : null,
    height: actual ? actual.h : null,
  };
}

// --all：把 --output 当基名，为每个背景预设派生一个文件名（out.png → out-aurora.png）
function presetOutputPath(base, label) {
  const dir = path.dirname(base);
  const ext = path.extname(base) || '.png';
  const stem = path.basename(base, ext);
  const safe = String(label).replace(/[^a-z0-9]+/gi, '-').replace(/^-+|-+$/g, '').toLowerCase() || 'bg';
  return path.join(dir, `${stem}-${safe}${ext}`);
}

// ---------- 主流程 ----------
function main() {
  const args = parseArgs(process.argv.slice(2));
  const strArg = (v) => (typeof v === 'string' ? v : '');
  // 严格数值解析：写错就报错，不静默回退。
  // （否则 `--padding 5O`（字母 O）会悄悄变成默认 56，调用方以为生效了）
  const numArg = (v, name, dflt, { integer = false, min = null } = {}) => {
    const s = strArg(v);
    if (s === '') return dflt;
    const n = Number(s);
    if (!Number.isFinite(n)) fail(2, `config/invalid-${name}`, `--${name} 需要数字，收到: ${s}`);
    if (integer && !Number.isInteger(n)) fail(2, `config/invalid-${name}`, `--${name} 需要整数，收到: ${s}`);
    if (min !== null && n < min) fail(2, `config/invalid-${name}`, `--${name} 不能小于 ${min}，收到: ${s}`);
    return n;
  };
  const wantJson = Boolean(args.json);
  const log = (msg) => { if (!wantJson) console.log(msg); };
  // 机读回执走 stdout、人类日志走 stderr，避免 agent 解析 stdout 时被日志污染
  const emit = (obj) => process.stdout.write(`${JSON.stringify(obj, null, 2)}\n`);
  // code 为稳定的字符串标识（供 agent 判断），exitCode 为进程退出码
  const fail = (exitCode, code, message, supportedFixes) => {
    if (wantJson) {
      emit({
        ok: false,
        command: 'frame',
        exitCode,
        error: { code, message, ...(supportedFixes ? { supportedFixes } : {}) },
      });
    }
    console.error(`✗ ${message}`);
    process.exit(exitCode);
  };

  // --list：列出所有可用取值后退出（agent 用来发现能力）
  if (args.list) {
    const info = {
      // 与成功/失败回执保持同一套顶层字段，agent 不必为 --list 写特例
      ok: true,
      command: 'frame',
      exitCode: 0,
      presets: ['browser', 'macos', 'device'],
      devices: Object.keys(DEVICES),
      themes: ['auto', 'light', 'dark'],
      ratios: Object.keys(RATIOS),
      backgrounds: Object.keys(GRADIENTS),
      backgroundForms: ['<preset>', 'solid:#rrggbb', 'linear:#a,#b[,#c]', 'none', 'light', 'dark'],
    };
    if (wantJson) {
      emit(info);
    } else {
      console.log(`presets     : ${info.presets.join(' ')}`);
      console.log(`devices     : ${info.devices.join(' ')}`);
      console.log(`themes      : ${info.themes.join(' ')}`);
      console.log(`ratios      : ${info.ratios.join(' ')}   （也支持任意 W:H / WxH）`);
      console.log(`backgrounds : ${info.backgrounds.join(' ')}`);
      console.log(`background  : ${info.backgroundForms.join('  |  ')}`);
    }
    process.exit(0);
  }

  if (typeof args.input !== 'string' || typeof args.output !== 'string') {
    fail(2, 'usage', '用法: node frame.js --input <png> --preset <browser|macos|device> --output <png> [--device iphone|ipad|macbook] [--title T] [--url U] [--theme auto|light|dark] [--trim] [--bg <preset|solid:#hex|linear:#a,#b|none>] [--angle 135] [--ratio twitter|1.91:1] [--width 1200] [--inset 12] [--radius 16] [--transparent] [--all] [--list] [--json] [--padding 56] [--chromium PATH]');
  }
  const input = args.input;
  const output = args.output;
  const preset = strArg(args.preset) || 'browser';
  const device = strArg(args.device) || 'iphone';
  const title = strArg(args.title);
  const url = strArg(args.url);
  const themeArg = strArg(args.theme) || 'auto';
  // --bg 优先；--background 为旧参数（light|dark），两者等价
  const bgArg = strArg(args.bg) || strArg(args.background);
  const pad = numArg(args.padding, 'padding', 56, { integer: true, min: 0 });
  const inset = numArg(args.inset, 'inset', 0, { integer: true, min: 0 });
  const radiusArg = numArg(args.radius, 'radius', NaN, { min: 0 });
  const angle = numArg(args.angle, 'angle', 135);
  const widthArg = numArg(args.width, 'width', 0, { integer: true, min: 40 });
  const wantTrim = Boolean(args.trim);
  const wantAll = Boolean(args.all);
  const wantTransparent = Boolean(args.transparent);

  if (!fs.existsSync(input)) fail(2, 'input/not-found', `输入文件不存在: ${input}`);
  if (!['browser', 'macos', 'device'].includes(preset)) fail(2, 'config/unknown-preset', `未知 preset: ${preset}（支持 browser / macos / device）`);
  if (preset === 'device' && !DEVICES[device]) fail(2, 'config/unknown-device', `未知设备: ${device}（支持 ${Object.keys(DEVICES).join(' / ')}）`);
  if (!['auto', 'light', 'dark'].includes(themeArg)) fail(2, 'config/unknown-theme', `未知 theme: ${themeArg}（支持 auto / light / dark）`);

  const ratioArg = strArg(args.ratio);
  const ratio = ratioArg ? parseRatio(ratioArg) : null;
  if (ratioArg && !ratio) fail(2, 'config/unknown-ratio', `未知 ratio: ${ratioArg}（支持 ${Object.keys(RATIOS).join(' / ')}，或任意 W:H / WxH）`);

  // 背景取值先做形式校验（不依赖主题 / Chromium），保证配置错误总是先于环境错误报出，
  // error.code 与机器是否装了 Chromium 无关。真正的深浅变体在主题确定后再解析。
  const bgSpecs = wantAll ? Object.keys(GRADIENTS) : [bgArg];
  for (const spec of bgSpecs) {
    if (!resolveBackground(spec, 'light', 135)) {
      fail(2, 'config/unknown-background', `未知背景: ${spec}（支持 ${Object.keys(GRADIENTS).join(' / ')}，或 solid:#hex / linear:#a,#b / none）`);
    }
  }

  const chromium = findChromium(args.chromium);
  if (!chromium) {
    fail(1, 'environment/chromium-missing', '未找到 Chromium。请安装 chromium 或设置 SHOTFRAME_CHROMIUM 环境变量指向浏览器可执行文件。', [
      '安装系统 Chromium（apt install chromium / brew install --cask chromium）',
      '或显式指定 --chromium /path/to/chrome',
    ]);
  }

  const buf = fs.readFileSync(input);
  const { w, h } = pngSize(buf);

  // --inset 不能把画面吃光（device 预设的衬边作用在设备屏幕宽度上，不是截图宽度）
  if (inset > 0) {
    const matteBase = preset === 'device' ? DEVICES[device].screenW : w;
    if (inset * 2 >= matteBase) {
      fail(2, 'config/invalid-inset', `--inset ${inset} 过大：衬边会把画面吃光（可用宽度仅 ${matteBase}px）`, [
        `改用小于 ${Math.floor(matteBase / 2)} 的 --inset`,
        '或去掉 --inset',
      ]);
    }
  }

  // 解码像素：主题自动检测 / --trim / --inset 需要
  const needPixels = themeArg === 'auto' || wantTrim || inset > 0;
  const decoded = needPixels ? decodePng(buf) : null;
  if (needPixels && !decoded && themeArg === 'auto') {
    log('提示: PNG 无法解码（仅支持 8-bit 非隔行），主题自动检测不可用，回退 light');
  }

  // --trim 先于主题检测：检测应基于裁剪后的真实 UI 区域，避免空白边干扰
  let trimBox = null;
  if (wantTrim && decoded) trimBox = computeTrimBox(decoded);

  // 主题解析：--theme 显式指定优先；auto 按亮度检测（限定在裁剪区内）；检测失败回退 light
  let theme;
  if (themeArg !== 'auto') theme = themeArg;
  else if (decoded) theme = detectTheme(decoded, trimBox);
  else theme = 'light';

  // --trim: 裁掉四角同色的均匀空白边
  let imgW = w, imgH = h;
  let dataUri = `data:image/png;base64,${buf.toString('base64')}`;
  let trimInfo = '无';
  let content = decoded;
  if (wantTrim) {
    if (!decoded) {
      trimInfo = '跳过(解码失败)';
    } else if (!trimBox) {
      trimInfo = '无边可裁';
    } else {
      const cropped = cropPng(decoded, trimBox);
      imgW = trimBox.width;
      imgH = trimBox.height;
      content = decodePng(cropped) || decoded;
      dataUri = `data:image/png;base64,${cropped.toString('base64')}`;
      trimInfo = `${w}x${h}->${imgW}x${imgH}`;
    }
  }

  // --inset: 采样（裁剪后）截图边缘最常见的颜色作为衬边色
  let insetColor = null;
  if (inset > 0) {
    if (!content) fail(2, 'input/undecodable', '--inset 需要解码截图以采样边缘颜色，但该 PNG 无法解码（仅支持 8-bit 非隔行）');
    insetColor = edgeColor(content) || '#ffffff';
  }

  // 主题已确定，解析最终背景（--all 时逐个预设各出一张）
  const variants = bgSpecs.map((spec) => ({ spec, ...resolveBackground(spec, theme, angle) }));

  // 画布：内容尺寸 + 四周留白，再按 --ratio 只扩不裁（多出来的空间由背景填充）
  const probe = buildHtml({
    imgDataUri: dataUri, imgW, imgH, preset, device, title, url, theme,
    bgCss: 'transparent', canvasW: 0, canvasH: 0, radius: radiusArg, inset, insetColor,
  });
  const canvas = fitToRatio(probe.contentW + pad * 2, probe.contentH + pad * 2, ratio);

  // --width：只缩小不放大。用设备像素比直接渲染到目标宽度（不做整图二次重采样）。
  // 缩放比有自己的下限，低于下限时**明确失败**而不是静默clamp
  // —— 否则 --width 100 会悄悄产出 322px，调用方以为拿到了 100px。
  const MIN_SCALE = 0.02;
  let scale = 2;
  if (widthArg) {
    const s = widthArg / canvas.width;
    if (s < 2) {
      if (s < MIN_SCALE) {
        fail(2, 'config/width-too-small', `--width ${widthArg} 需要 ${s.toFixed(4)} 倍缩放，低于下限 ${MIN_SCALE}；当前画布宽 ${canvas.width}px，最小可输出 ${Math.ceil(canvas.width * MIN_SCALE)}px`, [
          `改用 --width ${Math.ceil(canvas.width * MIN_SCALE)} 或更大`,
          '或先自行缩小输入截图',
          '或去掉 --ratio（比例会把画布撑大，进而压低可用缩放比）',
        ]);
      }
      scale = s;
    }
  }

  // 画布上限守卫：极端 --ratio / --padding 会算出天文数字的画布，Chromium 要么拒绝、
  // 要么先卡满 60s 超时再报一个语焉不详的 render/failed。这里提前失败，并给出可操作的改法。
  const outW = Math.round(canvas.width * scale);
  const outH = Math.round(canvas.height * scale);
  if (canvas.width > MAX_CANVAS_SIDE || canvas.height > MAX_CANVAS_SIDE) {
    fail(2, 'config/canvas-too-large', `画布 ${canvas.width}x${canvas.height} 超出单边上限 ${MAX_CANVAS_SIDE}px`, [
      `减小 --ratio（当前 ${ratioArg || '未指定'}）或 --padding（当前 ${pad}）`,
      '或先自行缩小输入截图',
    ]);
  }
  if (outW * outH > MAX_OUTPUT_PIXELS) {
    fail(2, 'config/output-too-large', `输出 ${outW}x${outH}（${Math.round(outW * outH / 1e6)}MP）超出上限 ${Math.round(MAX_OUTPUT_PIXELS / 1e6)}MP`, [
      '用 --width 指定更小的输出宽度',
      '或减小 --ratio / --padding',
    ]);
  }

  const outputs = [];
  for (const job of variants) {
    const transparent = wantTransparent || job.transparent;
    const target = wantAll ? presetOutputPath(output, job.label) : output;
    const built = buildHtml({
      imgDataUri: dataUri, imgW, imgH, preset, device, title, url, theme,
      bgCss: transparent ? 'transparent' : job.css,
      canvasW: canvas.width, canvasH: canvas.height,
      radius: radiusArg, inset, insetColor,
    });

    let res;
    try {
      res = renderFrame({
        chromium, html: built.html, output: target,
        cssW: canvas.width, cssH: canvas.height, scale, transparent,
      });
    } catch (e) {
      fail(1, 'render/failed', `Chromium 截图失败: ${e.message}`);
    }
    if (res.reason === 'no-output') {
      fail(1, 'output/missing', `Chromium 已退出但未产出可读的 PNG: ${target}（浏览器可能不可用，或输出路径不可写）`, [
        '确认 --chromium 指向真实可用的 Chrome/Chromium',
        '确认输出目录存在且可写',
      ]);
    }
    if (!res.verified) {
      const detail = `输出尺寸异常: 期望 ${res.expectedW}x${res.expectedH}, 实际 ${res.width}x${res.height}`;
      if (wantJson) {
        emit({
          ok: false,
          command: 'frame',
          exitCode: 3,
          error: {
            code: 'output/size-mismatch',
            message: `${detail}（无头窗口可能被显示环境钳制）`,
            supportedFixes: ['调大虚拟屏分辨率（如 Xvfb）', '减小输入截图宽度或 --width 后重试'],
          },
          output: path.resolve(target),
        });
      }
      console.error(`${detail}（无头窗口可能被显示环境钳制）。输出文件仍已生成，请人工检查构图。`);
      process.exit(3);
    }
    outputs.push({
      path: path.resolve(target),
      width: res.width,
      height: res.height,
      bytes: fs.statSync(target).size,
    });
  }

  // 收口「请求未被完全兑现」的两种情形——都明确告知，不静默。
  const warnings = [];
  if (wantAll && bgArg) {
    warnings.push(`--all 已指定，--bg ${bgArg} 被忽略（9 张已覆盖全部预设）`);
  }
  if (widthArg && outputs[0].width !== widthArg) {
    warnings.push(`--width ${widthArg} 未生效：只缩小不放大，当前 2x 画布宽仅 ${canvas.width * 2}px，实际输出 ${outputs[0].width}px`);
  }

  for (const o of outputs) {
    log(`✅ ${o.path}  ${o.width}x${o.height}  ${Math.round(o.bytes / 1024)} KB`);
  }
  for (const w of warnings) log(`   ⚠ ${w}`);
  log(`   preset=${preset}${preset === 'device' ? '/' + device : ''}  theme=${themeArg === 'auto' ? `auto->${theme}` : theme}  trim=${trimInfo}  bg=${variants.map((v) => v.label).join(',')}${inset > 0 ? `  inset=${inset}(${insetColor})` : ''}${ratioArg ? `  ratio=${ratioArg}` : ''}  scale=${scale}`);

  if (wantJson) {
    emit({
      ok: true,
      command: 'frame',
      exitCode: 0,
      input: path.resolve(input),
      preset,
      device: preset === 'device' ? device : null,
      theme: { requested: themeArg, resolved: theme },
      trim: { requested: wantTrim, applied: Boolean(trimBox), detail: trimInfo },
      background: {
        requested: bgArg || null,
        variants: variants.map((v) => v.label),
        transparent: wantTransparent || variants.some((v) => v.transparent),
        angle,
      },
      inset: inset > 0 ? { width: inset, color: insetColor } : null,
      ratio: ratioArg || null,
      padding: pad,
      scale,
      warnings,
      canvas: {
        cssWidth: canvas.width,
        cssHeight: canvas.height,
        width: outputs[0].width,
        height: outputs[0].height,
      },
      outputs,
    });
  }
}

// CLI 运行（require.main === module）时执行 main()；被 test/ require 时只导出内部逻辑
if (require.main === module) {
  main();
}

module.exports = {
  esc,
  pngSize,
  decodePng,
  encodePng,
  cropPng,
  computeTrimBox,
  detectTheme,
  parseRatio,
  fitToRatio,
  resolveBackground,
  edgeColor,
  presetOutputPath,
  GRADIENTS,
  RATIOS,
};
