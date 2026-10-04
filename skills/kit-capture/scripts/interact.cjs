#!/usr/bin/env node
// kit-capture interact — 剧本化网页截图（可选增强，非默认路径）
//
// 由 capture.sh 调用：puppeteer-core 在首次使用时自动安装到
// ~/.cache/kit-capture/runtime，通过 --rt <dir> 参数传入并按绝对路径 require，
// 不走 NODE_PATH（Git Bash/MSYS 不会转换 NODE_PATH 里的 POSIX 路径，在 Windows 上会失效）。
// 不污染项目依赖。浏览器复用与 browser 模式相同的探测/自举缓存。
//
// 用法（全部由 capture.sh 组装）:
//   node interact.cjs --rt <runtime目录> --chromium <bin> --url <u> --out <png>
//     [--width 1440] [--height 900] [--dsf 1] [--selector <css>] [--fullpage]
//     [--act 'click:选择器'] [--act 'wait:毫秒'] [--act 'waitfor:选择器'] [--act 'scroll:像素']
'use strict';

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

// 先尝试 <rt>/node_modules/puppeteer-core（capture.sh 安装位置，全平台一致），
// 再退回普通解析（开发环境直接装了依赖时也能跑）
let puppeteer;
const rtPptr = a.rt ? require('path').join(a.rt, 'node_modules', 'puppeteer-core') : null;
try {
  puppeteer = rtPptr ? require(rtPptr) : require('puppeteer-core');
} catch (e) {
  try {
    puppeteer = require('puppeteer-core');
  } catch (e2) {
    console.error('✗ 缺少 puppeteer-core（应由 capture.sh 安装到 ~/.cache/kit-capture/runtime）');
    process.exit(2);
  }
}

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
      else if (t === 'wait') await new Promise((r) => setTimeout(r, Number(v)));
      else if (t === 'waitfor') await page.waitForSelector(v, { timeout: 15000 });
      else if (t === 'scroll') await page.evaluate((y) => window.scrollBy(0, Number(y)), v);
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
