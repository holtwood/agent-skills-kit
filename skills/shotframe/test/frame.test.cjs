'use strict';
/**
 * shotframe — frame.js 纯逻辑单元测试（node:test，纯 Node，无需 Chromium）
 *
 * 覆盖自研 PNG 解码/裁剪/重编码/主题检测等无头逻辑，重点是
 * `--trim` 对灰度+alpha PNG 的透明度保留（回归防护）。
 *
 * 运行: node --test skills/shotframe/test/
 */
const test = require('node:test');
const assert = require('node:assert');
const zlib = require('node:zlib');
// 断言路径时统一走 path.join，避免 Windows 反斜杠导致测试误报
const pathJoin = require('node:path').join;
const {
  esc, decodePng, encodePng, cropPng, computeTrimBox, detectTheme,
  parseRatio, fitToRatio, resolveBackground, edgeColor, presetOutputPath,
  GRADIENTS, RATIOS,
} = require('../scripts/frame.js');

// ---------- 测试用最小 PNG 构造器（独立实现，不信任被测代码） ----------
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
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crc]);
}
function buildPng(width, height, colorType, rows) {
  // rows: 每行原始像素字节（不含 filter 字节，统一用 filter 0）
  const channels = colorType === 4 ? 2 : 3;
  const stride = width * channels;
  const raw = Buffer.alloc((stride + 1) * height);
  rows.forEach((row, y) => {
    raw[y * (stride + 1)] = 0;
    row.copy(raw, y * (stride + 1) + 1);
  });
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;          // bit depth
  ihdr[9] = colorType;  // 2=RGB, 4=灰度+alpha
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 6 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// 40x36 灰度+alpha：四周 2px 均匀纯色边(200, opaque) + 内部 36x32 内容
// 内部左侧 alpha=128，右侧 alpha=0（全透明），用于验证 --trim 不丢 alpha
// 尺寸需满足 computeTrimBox 约束（每边最多裁 20%，裁剪后至少 32px）
function grayAlphaFixture() {
  const rows = [];
  for (let y = 0; y < 36; y++) {
    const row = Buffer.alloc(40 * 2);
    for (let x = 0; x < 40; x++) {
      const isBorder = x < 2 || x >= 38 || y < 2 || y >= 34;
      if (isBorder) {
        row[x * 2] = 200; row[x * 2 + 1] = 255;
      } else {
        row[x * 2] = 60; row[x * 2 + 1] = x < 20 ? 128 : 0;
      }
    }
    rows.push(row);
  }
  return buildPng(40, 36, 4, rows);
}

test('灰度+alpha PNG 可解码（colorType 4）', () => {
  const d = decodePng(grayAlphaFixture());
  assert.ok(d, '灰度+alpha 应能解码');
  assert.equal(d.width, 40);
  assert.equal(d.height, 36);
  assert.equal(d.channels, 2);
});

test('computeTrimBox 裁掉四周均匀纯色边', () => {
  const d = decodePng(grayAlphaFixture());
  const box = computeTrimBox(d);
  assert.ok(box, '应检测到纯色边');
  assert.deepEqual([box.left, box.top, box.width, box.height], [2, 2, 36, 32]);
});

test('cropPng 保留灰度+alpha 的透明度（回归: --trim 丢 alpha）', () => {
  const d = decodePng(grayAlphaFixture());
  const out = cropPng(d, { left: 2, top: 2, width: 36, height: 32 });
  const d2 = decodePng(out);
  assert.ok(d2, '裁剪产物应可解码');
  assert.equal(d2.width, 36);
  assert.equal(d2.height, 32);
  assert.equal(d2.channels, 4, '裁剪后应重编码为 RGBA 以保留 alpha');
  // 直接读 rows 验证 alpha（getPixel 不暴露 alpha 通道）
  const stride = 36 * 4;
  assert.equal(d2.rows[0 * stride + 0 * 4 + 3], 128, '半透明像素 alpha 应保留');
  assert.equal(d2.rows[0 * stride + 17 * 4 + 3], 128, '半透明像素 alpha 应保留');
  assert.equal(d2.rows[0 * stride + 18 * 4 + 3], 0, '全透明像素 alpha 应保留为 0，而不是被丢弃成 255');
  assert.equal(d2.rows[31 * stride + 35 * 4 + 3], 0, '右下角全透明像素 alpha 应保留');
});

test('RGB PNG 解码→重编码→再解码 像素不变', () => {
  const rows = [
    Buffer.from([255, 0, 0, 0, 0, 255]),
    Buffer.from([0, 255, 0, 128, 128, 128]),
  ];
  const png = buildPng(2, 2, 2, rows);
  const d = decodePng(png);
  assert.ok(d);
  assert.equal(d.channels, 3);
  const re = encodePng(2, 2, 3, d.rows);
  const d2 = decodePng(re);
  assert.deepEqual([...d2.rows], [...d.rows]);
});

test('detectTheme 按整体亮度选深浅', () => {
  const light = buildPng(2, 2, 2, [
    Buffer.from([240, 240, 240, 250, 250, 250]),
    Buffer.from([245, 245, 245, 255, 255, 255]),
  ]);
  const dark = buildPng(2, 2, 2, [
    Buffer.from([10, 10, 10, 20, 20, 20]),
    Buffer.from([15, 15, 15, 5, 5, 5]),
  ]);
  assert.equal(detectTheme(decodePng(light)), 'light');
  assert.equal(detectTheme(decodePng(dark)), 'dark');
});

test('非法输入 decodePng 返回 null（不抛异常）', () => {
  assert.equal(decodePng(Buffer.from('not a png')), null);
  assert.equal(decodePng(Buffer.alloc(8)), null);
});

// ---------- --ratio / --bg / --inset 的纯逻辑 ----------

test('parseRatio 支持命名比例与任意 W:H / WxH', () => {
  assert.deepEqual(parseRatio('og'), [1.91, 1]);
  assert.deepEqual(parseRatio('twitter'), [16, 9]);
  assert.deepEqual(parseRatio('story'), [9, 16]);
  assert.deepEqual(parseRatio('16:9'), [16, 9]);
  assert.deepEqual(parseRatio('4x5'), [4, 5]);
  assert.deepEqual(parseRatio(' 1.91:1 '), [1.91, 1]);
  // 非法值必须返回 null，由调用方报错退出（而不是静默按默认值渲染）
  assert.equal(parseRatio('7'), null);
  assert.equal(parseRatio('16:'), null);
  assert.equal(parseRatio('a:b'), null);
  assert.equal(parseRatio('16:0'), null);
  assert.equal(parseRatio(''), null);
  assert.equal(parseRatio(null), null);
});

test('fitToRatio 只扩画布不裁剪，且内容保持居中（尺寸只增不减）', () => {
  // 内容偏"高" → 扩宽
  assert.deepEqual(fitToRatio(1000, 1000, [1.91, 1]), { width: 1910, height: 1000 });
  // 内容偏"宽" → 扩高
  assert.deepEqual(fitToRatio(1600, 900, [1, 1]), { width: 1600, height: 1600 });
  // 正好匹配 → 原样
  assert.deepEqual(fitToRatio(1600, 900, [16, 9]), { width: 1600, height: 900 });
  // 无比例 → 原样
  assert.deepEqual(fitToRatio(123, 45, null), { width: 123, height: 45 });
  // 任何情况下都不小于原始尺寸
  const out = fitToRatio(1200, 800, [9, 16]);
  assert.ok(out.width >= 1200 && out.height >= 800);
});

test('resolveBackground 覆盖预设/纯色/自定义渐变/透明/旧参数', () => {
  const preset = resolveBackground('aurora', 'dark', 135);
  assert.match(preset.css, /^linear-gradient\(135deg,/);
  assert.equal(preset.transparent, false);
  // 同一预设的深浅变体必须不同（否则主题自适应形同虚设）
  assert.notEqual(resolveBackground('aurora', 'light', 135).css, resolveBackground('aurora', 'dark', 135).css);

  assert.equal(resolveBackground('solid:#0f172a', 'light', 135).css, '#0f172a');

  const lin = resolveBackground('linear:#a8edea,#fed6e3', 'light', 45);
  assert.equal(lin.css, 'linear-gradient(45deg,#a8edea,#fed6e3)');

  assert.equal(resolveBackground('none', 'light', 135).transparent, true);
  // 旧参数 --background light|dark 仍等价于主题默认背景
  assert.equal(resolveBackground('dark', 'light', 135).css, resolveBackground('', 'dark', 135).css);

  assert.equal(resolveBackground('nope', 'light', 135), null);
  assert.equal(resolveBackground('solid:zzz', 'light', 135), null);
  assert.equal(resolveBackground('linear:#fff', 'light', 135), null, '单色渐变应视为非法');
});

test('--angle 对内置主题背景同样生效（回归：曾经是静默空操作）', () => {
  assert.notEqual(resolveBackground('', 'light', 45).css, resolveBackground('', 'light', 135).css);
  assert.match(resolveBackground('', 'light', 45).css, /45deg/);
  assert.match(resolveBackground('dark', 'light', 30).css, /30deg/);
  assert.equal(resolveBackground('', 'light', 45).angle, 45);
});

test('edgeColor 采样出截图四周最常见的颜色（--inset 用）', () => {
  // 40x36：四周 2px 为 (200,30,40)，内部为白色
  const rows = [];
  for (let y = 0; y < 36; y++) {
    const row = Buffer.alloc(40 * 3);
    for (let x = 0; x < 40; x++) {
      const isBorder = x < 2 || x >= 38 || y < 2 || y >= 34;
      const [r, g, b] = isBorder ? [200, 30, 40] : [255, 255, 255];
      row[x * 3] = r; row[x * 3 + 1] = g; row[x * 3 + 2] = b;
    }
    rows.push(row);
  }
  const color = edgeColor(decodePng(buildPng(40, 36, 2, rows)));
  assert.equal(color, 'rgb(200,30,40)');
  assert.equal(edgeColor(null), null);
});

test('presetOutputPath 为 --all 派生文件名', () => {
  assert.equal(presetOutputPath('out.png', 'aurora'), pathJoin('out-aurora.png'));
  assert.equal(presetOutputPath('a/b/shot.PNG', 'sky'), pathJoin('a/b/shot-sky.PNG'));
  // label 里的非法字符要清理干净，避免生成奇怪文件名
  assert.equal(presetOutputPath('out.png', 'solid:#0f172a'), pathJoin('out-solid-0f172a.png'));
});

test('esc 阻断 HTML 注入（--title / --url 落在内容上下文）', () => {
  // 不能闭合标签 / 不能提前结束 <style>：这是渲染器的注入面
  assert.equal(esc('</style><script>alert(1)</script>'), '&lt;/style&gt;&lt;script&gt;alert(1)&lt;/script&gt;');
  assert.equal(esc('</div><img src=x onerror=alert(1)>'), '&lt;/div&gt;&lt;img src=x onerror=alert(1)&gt;');
  // & 必须先于 < > 替换，否则会二次转义
  assert.equal(esc('a & <b>'), 'a &amp; &lt;b&gt;');
  // 内容上下文里引号无害，保持原样即可
  assert.equal(esc('say "hi" & \'bye\''), 'say "hi" &amp; \'bye\'');
  assert.equal(esc(undefined), 'undefined');
});

test('预设数据完整：每个渐变都有深浅两套，每个比例都是正数对', () => {
  for (const [name, g] of Object.entries(GRADIENTS)) {
    assert.ok(g.light && g.dark, `${name} 缺少 light/dark 变体`);
    assert.match(g.light, /^linear-gradient\(ANGLEdeg,/, `${name} light 模板占位符丢失`);
    assert.match(g.dark, /^linear-gradient\(ANGLEdeg,/, `${name} dark 模板占位符丢失`);
  }
  for (const [name, [w, h]] of Object.entries(RATIOS)) {
    assert.ok(w > 0 && h > 0, `${name} 比例非法`);
  }
});
