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
const { decodePng, encodePng, cropPng, computeTrimBox, detectTheme } = require('../scripts/frame.js');

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
