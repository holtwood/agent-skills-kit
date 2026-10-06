#!/usr/bin/env python3
"""embed_images.py — 将公众号 HTML 转换为可直接复制粘贴的 Base64 内联版本，并确保 span leaf 合规。

用法:
    python3 embed_images.py <文章目录>
    python3 embed_images.py <文章目录> --html custom.html --out custom-embedded.html
"""

import argparse
import base64
import os
import re
import sys

def process_html(article_dir, html_name="article-gzh.html", out_name="article-gzh-embedded.html"):
    src_path = os.path.join(article_dir, html_name)
    out_path = os.path.join(article_dir, out_name)

    if not os.path.exists(src_path):
        print(f"Error: {src_path} not found.", file=sys.stderr)
        return 1

    with open(src_path, "r", encoding="utf-8") as f:
        html = f.read()

    # 1. 确保所有非代码区的 CJK 文本都被 <span leaf=""> 包裹（先剥除已有 leaf 标签，再单层包裹，确保幂等不嵌套）
    # 注：不剥 font-family —— 页面字体由主题容器的系统无衬线字体栈声明，
    # 衬线/异体栈由 validate_gzh_html.py 负责警告，这里保留原样保证预览与粘贴一致。
    while re.search(r'<span leaf=\"\">(.*?)</span>', html, re.DOTALL):
        html = re.sub(r'<span leaf=\"\">(.*?)</span>', r'\1', html, flags=re.DOTALL)

    def wrap_cjk(match):
        text = match.group(1)
        if not text.strip():
            return match.group(0)
        # 检查是否包含中文字符
        if re.search(r'[\u4e00-\u9fa5]', text):
            return f'><span leaf=\"\">{text}</span><'
        return match.group(0)

    # 仅在 > 和 < 之间的纯文本节点执行包裹检测
    clean_html = re.sub(r'>([^<]+)<', wrap_cjk, html)

    # 同步回写清理后的 clean html 到 src_path（保证两份产物一致）
    with open(src_path, "w", encoding="utf-8") as f:
        f.write(clean_html)

    # 2. 将相对图片路径替换为 Base64 Data URI
    embedded_count = 0
    def replace_img(match):
        nonlocal embedded_count
        rel_path = match.group(1)
        full_path = os.path.join(article_dir, rel_path)
        if os.path.exists(full_path):
            ext = rel_path.split('.')[-1].lower()
            mime = "image/png" if ext == "png" else ("image/jpeg" if ext in ["jpg", "jpeg"] else f"image/{ext}")
            with open(full_path, "rb") as img_f:
                b64 = base64.b64encode(img_f.read()).decode("utf-8")
            embedded_count += 1
            return f'src="data:{mime};base64,{b64}"'
        else:
            print(f"Warning: Image file not found: {full_path}", file=sys.stderr)
            return match.group(0)

    embedded_html = re.sub(r'src=[\'"]([^\'"]+\.(?:png|jpg|jpeg|gif|webp))[\'"]', replace_img, clean_html, flags=re.IGNORECASE)

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(embedded_html)

    print(f"✅ 成功生成内联交付文件: {out_name} (内联 {embedded_count} 张图片, 大小: {len(embedded_html)/1024:.1f} KB)")
    return 0

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert article-gzh.html to Base64 embedded HTML.")
    parser.add_argument("dir", help="Path to article directory")
    parser.add_argument("--html", default="article-gzh.html", help="Source HTML file name")
    parser.add_argument("--out", default="article-gzh-embedded.html", help="Output embedded HTML file name")
    args = parser.parse_args()

    sys.exit(process_html(args.dir, args.html, args.out))
