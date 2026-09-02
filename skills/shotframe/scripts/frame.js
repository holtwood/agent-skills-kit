#!/usr/bin/env node
/**
 * shotframe — 截图套框渲染器（零 npm 依赖）
 *
 * 用法:
 *   node frame.js --input <png> --preset <browser|macos|device> --output <png> \
 *     [--device iphone|ipad|macbook] [--title T] [--url U] \
 *     [--theme auto|light|dark] [--trim] [--background light|dark] [--padding 56] [--chromium PATH]
 *
 * --theme auto: 按截图亮度自动选择 chrome(标签页/标题栏)与背景的深浅配色
 * --trim:       裁掉输入四周与角落同色的均匀空白边(桌面背景/视口留白)后再套框
 */
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const zlib = require('zlib');
const { execFileSync } = require('child_process');

// ---------- 参数解析 ----------
const VALUE_FLAGS = new Set(['input', 'output', 'preset', 'device', 'title', 'url', 'theme', 'background', 'padding', 'chromium']);
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
  const outCh = channels === 4 ? 4 : 3; // 保留 alpha，其余统一 RGB
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
      for (const layout of ['chrome-linux64', 'chrome-linux']) {
        const exe = path.join(cache, ver, layout, 'chrome');
        if (fs.existsSync(exe)) { out.push(exe); break; }
      }
    }
  } catch (_) { /* cache 不存在时忽略 */ }
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

// ---------- HTML 模板 ----------
function esc(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function buildHtml({ imgDataUri, imgW, imgH, preset, device, title, url, theme, bgOverride, pad }) {
  const T = THEMES[theme] || THEMES.light;
  const bg = bgOverride || T.bg;

  let inner = '';
  let cssW = 0;
  let cssH = 0;
  let deviceCss = '';

  if (preset === 'device') {
    const d = DEVICES[device];
    const screenW = d.screenW;
    const screenH = imgW > 0 ? Math.round((screenW * imgH) / imgW) : 0;
    const b = d.bezel;

    if (device === 'macbook') {
      cssW = screenW + b * 2 + pad * 2;
      cssH = b + screenH + b + d.chin + pad * 2;
      inner = `<div class="mac" style="--r:${d.radius}px;--sr:${d.screenRadius}px;--b:${b}px;--c:${d.chin}px;width:${screenW + b * 2}px">
  <div class="lid"><div class="screen"><img src="${imgDataUri}"><div class="notch"></div></div></div>
  <div class="chin"><div class="logo"></div></div>
</div>`;
    } else {
      cssW = screenW + b * 2 + pad * 2;
      cssH = screenH + b * 2 + pad * 2;
      const topAccent =
        d.notch === 'island' ? '<div class="island"></div>'
        : d.notch === 'dot' ? '<div class="camdot"></div>' : '';
      const btns = d.buttons ? '<div class="btn lt"></div><div class="btn lm"></div><div class="btn rt"></div>' : '';
      const home = d.home ? '<div class="homeind"></div>' : '';
      inner = `<div class="device" style="--r:${d.radius}px;--sr:${d.screenRadius}px;--b:${b}px;width:${screenW + b * 2}px">
  <div class="bezel">
    <div class="screen"><img src="${imgDataUri}"></div>
    ${topAccent}${home}
  </div>
  ${btns}
</div>`;
    }

    deviceCss = `
      .device, .mac { position:relative; flex:none; }
      .bezel { background:#0b0f14; border-radius:var(--r); padding:var(--b); border:1px solid #1f2937; box-shadow:${T.shadow}; position:relative; }
      .device .screen, .lid .screen { border-radius:var(--sr); overflow:hidden; line-height:0; background:#000; }
      .device img, .mac img { display:block; width:100%; height:auto; }
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
    const radius = 14;
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
    cssW = imgW + pad * 2;
    cssH = imgH + pad * 2 + topBarH;
    inner = `<div class="win">${chrome}<div class="content"><img src="${imgDataUri}"></div></div>`;

    deviceCss = `
      .win {
        background:${T.winBg}; border-radius:${radius}px; overflow:hidden;
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
      img { display:block; width:100%; height:auto; }`;
  }

  return {
    html: `<!doctype html><html><head><meta charset="utf-8"><style>
      * { margin:0; padding:0; box-sizing:border-box; }
      body {
        background: ${bg};
        width:${cssW}px; height:${cssH}px;
        display:flex; align-items:center; justify-content:center;
        font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','PingFang SC','Microsoft YaHei',sans-serif;
        overflow:hidden;
      }
      ${deviceCss}
    </style></head><body>
      ${inner}
    </body></html>`,
    cssW,
    cssH,
  };
}

// ---------- 主流程 ----------
function main() {
  const args = parseArgs(process.argv.slice(2));

  if (typeof args.input !== 'string' || typeof args.output !== 'string') {
    console.error('用法: node frame.js --input <png> --preset <browser|macos|device> --output <png> [--device iphone|ipad|macbook] [--title T] [--url U] [--theme auto|light|dark] [--trim] [--background light|dark] [--padding 56] [--chromium PATH]');
    process.exit(2);
  }
  const input = args.input;
  const output = args.output;
  const strArg = (v) => (typeof v === 'string' ? v : '');
  const preset = strArg(args.preset) || 'browser';
  const device = strArg(args.device) || 'iphone';
  const title = strArg(args.title);
  const url = strArg(args.url);
  const themeArg = strArg(args.theme) || 'auto';
  const bgArg = strArg(args.background);
  const pad = /^\d+$/.test(strArg(args.padding)) ? Number(args.padding) : 56;
  const wantTrim = Boolean(args.trim);

  if (!fs.existsSync(input)) {
    console.error(`输入文件不存在: ${input}`);
    process.exit(2);
  }
  if (preset !== 'browser' && preset !== 'macos' && preset !== 'device') {
    console.error(`未知 preset: ${preset}（支持 browser / macos / device）`);
    process.exit(2);
  }
  if (preset === 'device' && !DEVICES[device]) {
    console.error(`未知设备: ${device}（支持 ${Object.keys(DEVICES).join(' / ')}）`);
    process.exit(2);
  }
  if (!['auto', 'light', 'dark'].includes(themeArg)) {
    console.error(`未知 theme: ${themeArg}（支持 auto / light / dark）`);
    process.exit(2);
  }
  if (bgArg && bgArg !== 'light' && bgArg !== 'dark') {
    console.error(`未知 background: ${bgArg}（支持 light / dark）`);
    process.exit(2);
  }

  const chromium = findChromium(args.chromium);
  if (!chromium) {
    console.error('未找到 Chromium。请安装 chromium 或设置 SHOTFRAME_CHROMIUM 环境变量指向浏览器可执行文件。');
    process.exit(1);
  }

  const buf = fs.readFileSync(input);
  const { w, h } = pngSize(buf);

  // 解码像素：主题自动检测或 --trim 需要
  const needPixels = themeArg === 'auto' || wantTrim;
  const decoded = needPixels ? decodePng(buf) : null;
  if (needPixels && !decoded) {
    console.error('提示: PNG 无法解码（仅支持 8-bit 非隔行），主题自动检测与 --trim 不可用');
  }

  // --trim 先于主题检测：检测应基于裁剪后的真实 UI 区域，避免空白边干扰
  let trimBox = null;
  if (wantTrim && decoded) {
    trimBox = computeTrimBox(decoded);
  }

  // 主题解析：--theme 显式指定优先；auto 按亮度检测（限定在裁剪区内）；检测失败回退 light
  let theme;
  if (themeArg !== 'auto') {
    theme = themeArg;
  } else if (decoded) {
    theme = detectTheme(decoded, trimBox);
  } else {
    theme = 'light';
  }
  // --background 为旧参数：仅覆盖外层背景，chrome 仍跟随主题
  const bgOverride = bgArg ? THEMES[bgArg].bg : undefined;

  // --trim: 裁掉四角同色的均匀空白边
  let imgW = w, imgH = h;
  let dataUri = `data:image/png;base64,${buf.toString('base64')}`;
  let trimInfo = '无';
  if (wantTrim) {
    if (!decoded) {
      trimInfo = '跳过(解码失败)';
    } else if (!trimBox) {
      trimInfo = '无边可裁';
    } else {
      imgW = trimBox.width;
      imgH = trimBox.height;
      dataUri = `data:image/png;base64,${cropPng(decoded, trimBox).toString('base64')}`;
      trimInfo = `${w}x${h}->${imgW}x${imgH}`;
    }
  }

  const { html, cssW, cssH } = buildHtml({ imgDataUri: dataUri, imgW, imgH, preset, device, title, url, theme, bgOverride, pad });

  const tmpHtml = path.join(os.tmpdir(), `shotframe-${process.pid}-${crypto.randomBytes(6).toString('hex')}.html`);
  fs.writeFileSync(tmpHtml, html, { flag: 'wx', mode: 0o600 });

  fs.mkdirSync(path.dirname(path.resolve(output)), { recursive: true });

  const renderOnce = (winW, winH) => {
    execFileSync(chromium, [
      '--headless=new',
      '--disable-gpu',
      '--no-sandbox',
      '--hide-scrollbars',
      '--force-device-scale-factor=2',
      `--window-size=${winW},${winH}`,
      `--screenshot=${path.resolve(output)}`,
      `file://${tmpHtml}`,
    ], { stdio: 'ignore', timeout: 60000 });
  };

  // 渲染 + 尺寸校验：无头窗口可能被显示环境钳制，自动校正窗口尺寸重试一次
  const expectedW = cssW * 2;
  const expectedH = cssH * 2;
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
      if (actual.w === expectedW && actual.h === expectedH) {
        verified = true;
        break;
      }
      // 按差值校正窗口尺寸后重试（防负值/过小值导致 Chromium 报错）
      winW = Math.max(200, winW + Math.round(cssW - actual.w / 2));
      winH = Math.max(200, winH + Math.round(cssH - actual.h / 2));
    }
  } catch (e) {
    console.error('Chromium 截图失败:', e.message);
    process.exit(1);
  } finally {
    fs.rmSync(tmpHtml, { force: true });
  }

  if (!verified) {
    console.error(`输出尺寸异常: 期望 ${expectedW}x${expectedH}, 实际 ${actual ? `${actual.w}x${actual.h}` : '无法读取'}（无头窗口可能被显示环境钳制）。输出文件仍已生成，请人工检查构图。`);
    process.exit(3);
  }

  const outSize = fs.statSync(output).size;
  console.log(`✅ ${preset}${preset === 'device' ? '/' + device : ''} 框架完成: ${output} (${Math.round(outSize / 1024)} KB, ${expectedW}x${expectedH}, theme=${themeArg === 'auto' ? `auto->${theme}` : theme}, trim=${trimInfo})`);
}

main();
