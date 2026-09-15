#!/usr/bin/env node
// kit-wsl-capture interact — 剧本化网页截图（可选增强，非默认路径）
//
// 由 capture.sh 调用：puppeteer-core 在首次使用时自动安装到
// ~/.cache/kit-wsl-capture/runtime（NODE_PATH 指向其 node_modules），
// 不污染项目依赖。浏览器复用与 browser 模式相同的探测/自举缓存。
//
// 用法（全部由 capture.sh 组装）:
//   node interact.cjs --chromium <bin> --url <u> --out <png>
//     [--width 1440] [--height 900] [--dsf 1] [--selector <css>] [--fullpage]
//     [--act 'click:选择器'] [--act 'wait:毫秒'] [--act 'waitfor:选择器'] [--act 'scroll:像素']
'use strict';

// CJS + NODE_PATH：capture.sh 以 NODE_PATH=~/.cache/kit-wsl-capture/runtime/node_modules 调用，
// require 直接解析到缓存目录里按需安装的 puppeteer-core
let puppeteer;
try {
  puppeteer = require('puppeteer-core');
} catch (e) {
  console.error('✗ 缺少 puppeteer-core（应由 capture.sh 安装到 ~/.cache/kit-wsl-capture/runtime）');
  process.exit(2);
}

function parse(argv) {
  const a = { acts: [] };
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (k === '--act') a.acts.push(argv[++i] || '');
    else if (k === '--fullpage') a.fullpage = true;
    else if (k.startsWith('--')) a[k.slice(2)] = argv[++i];
  }
  return a;
}

const a = parse(process.argv.slice(2));

(async () => {
  // chrome-headless-shell 只支持 shell 模式；常规 Chrome 走新 headless
  const isShell = /headless-shell/i.test(a.chromium || '');
  const browser = await puppeteer.launch({
    executablePath: a.chromium,
    headless: isShell ? 'shell' : true,
    args: ['--no-sandbox', '--disable-gpu', '--hide-scrollbars'],
  });
  try {
    const page = await browser.newPage();
    await page.setViewport({
      width: parseInt(a.width, 10) || 1440,
      height: parseInt(a.height, 10) || 900,
      deviceScaleFactor: parseFloat(a.dsf) || 1,
    });
    await page.goto(a.url, { waitUntil: 'networkidle2', timeout: 45000 });
    // 按命令行出现顺序执行剧本动作
    for (const act of a.acts) {
      const i = act.indexOf(':');
      const t = i < 0 ? act : act.slice(0, i);
      const v = i < 0 ? '' : act.slice(i + 1);
      if (t === 'click') await page.click(v);
      else if (t === 'wait') await new Promise((r) => setTimeout(r, parseInt(v, 10) || 1000));
      else if (t === 'waitfor') await page.waitForSelector(v, { timeout: 15000 });
      else if (t === 'scroll') await page.evaluate((y) => window.scrollBy(0, parseInt(y, 10) || 600), v);
      else throw new Error(`未知动作: ${act}`);
    }
    if (a.selector) {
      const el = await page.$(a.selector);
      if (!el) throw new Error(`选择器未命中任何元素: ${a.selector}`);
      await el.screenshot({ path: a.out });
    } else {
      await page.screenshot({ path: a.out, fullPage: Boolean(a.fullpage) });
    }
  } finally {
    await browser.close();
  }
})().catch((e) => {
  console.error(`✗ ${e.message}`);
  process.exit(1);
});
