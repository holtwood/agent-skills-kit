#!/usr/bin/env python3
"""
project-hub — 把仓库列表生成自包含导航主页（Python 标准库，零依赖）

用法:
  gen-hub.py <repos.json> <out.html> [--desc-zh desc_zh.json] [--title 标题] [--owner 用户名]
             [--group-by language|type] [--featured a,b,c]
"""
import argparse
import html
import json
import sys

LANG_COLORS = {
    'JavaScript': '#f1e05a', 'TypeScript': '#3178c6', 'Python': '#3572A5',
    'Go': '#00ADD8', 'Rust': '#dea584', 'Shell': '#89e051', 'C': '#555555',
    'C++': '#f34b7d', 'Vue': '#41b883', 'React': '#61dafb', 'HTML': '#e34c26',
    'CSS': '#563d7c', 'Jupyter Notebook': '#DA5B0B', 'PHP': '#4F5D95', 'Ruby': '#701516',
    'Java': '#b07219', 'Kotlin': '#A97BFF', 'Swift': '#F05138', 'Dart': '#00B4AB',
}

def esc(s):
    return html.escape(str(s) if s is not None else '', quote=True)

def load_desc(path):
    if not path:
        return {}
    try:
        with open(path, encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f'⚠ 无法读取中文描述文件 {path}（{e}），将使用原文描述', file=sys.stderr)
        return {}

def card(r, owner=''):
    lang = r.get('language') or ''
    color = LANG_COLORS.get(lang, '#94a3b8')
    desc = r.get('description') or '（无描述）'
    stars = r.get('stargazersCount') or 0
    updated = (r.get('updatedAt') or '')[:10]
    badges = ''
    if r.get('fork'):
        badges += '<span class="b fork">Fork</span>'
    if r.get('archived'):
        badges += '<span class="b arc">归档</span>'
    # url 缺失/为空时回退拼接：有 owner 用 owner/name，保证链接指向正确仓库
    url = r.get('url') or (f"https://github.com/{owner}/{r.get('name', '')}".rstrip('/') if owner else f"https://github.com/{r.get('name', '')}")
    return f'''<a class="card" href="{esc(url)}" target="_blank" rel="noopener">
  <div class="head"><span class="name">{esc(r['name'])}</span>{badges}</div>
  <p class="desc">{esc(desc)}</p>
  <div class="meta">
    <span class="lang"><i style="background:{color}"></i>{esc(lang)}</span>
    <span class="stars">★ {stars:,}</span>
    <span class="time">{updated}</span>
  </div>
</a>'''

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('repos_json')
    ap.add_argument('out_html')
    ap.add_argument('--desc-zh')
    ap.add_argument('--title', default='我的项目')
    ap.add_argument('--owner', default='')
    ap.add_argument('--group-by', default='type', choices=['type', 'language'])
    ap.add_argument('--featured', default='', help='精选仓库名（逗号分隔），渲染在页面顶部的精选区')
    args = ap.parse_args()

    with open(args.repos_json, encoding='utf-8') as f:
        repos = json.load(f)
    if not isinstance(repos, list):
        print('✗ repos.json 必须是 JSON 数组（gh repo list 的输出格式）', file=sys.stderr)
        sys.exit(2)
    repos = [r for r in repos if isinstance(r, dict)]

    desc_zh = load_desc(args.desc_zh)
    featured_names = [n.strip() for n in args.featured.split(',') if n.strip()]

    def group_of(r):
        # language 模式纯按语言分组（Fork/归档状态以卡片角标展示，不再单列分组）
        if args.group_by == 'language':
            return r.get('language') or '其他'
        if r.get('archived'):
            return '归档'
        if r.get('fork'):
            return 'Fork'
        name = r.get('name', '')
        if name.startswith('awesome-') or 'awesome' in name:
            return 'Awesome 合集'
        if name.startswith('page-') or name in {'index', 'home', 'homepage'}:
            return '个人站点'
        return '项目'

    for r in repos:
        if desc_zh and r.get('name') in desc_zh:
            r['description'] = desc_zh[r['name']]

    # 精选区：按 --featured 顺序挑出仓库，并从普通分组中移除避免重复
    featured = []
    if featured_names:
        by_name = {r.get('name'): r for r in repos}
        for n in featured_names:
            if n in by_name:
                featured.append(by_name[n])
        featured_names_set = set(featured_names)
        repos = [r for r in repos if r.get('name') not in featured_names_set]

    grouped = {}
    for r in repos:
        grouped.setdefault(group_of(r), []).append(r)

    order = sorted(grouped.keys(), key=lambda g: {'个人站点': 0, '项目': 1, 'Awesome 合集': 2, 'Fork': 3, '归档': 4, '其他': 99}.get(g, 50))
    total = len(repos) + len(featured)

    sections = []
    if featured:
        sections.append('<h2 class="grp feat-h" data-cat="⭐ 精选">⭐ 精选 <span class="n">%d</span></h2><div class="grid" data-g="feat">%s</div>'
                        % (len(featured), ''.join(card(r, args.owner) for r in sorted(featured, key=lambda x: x.get('stargazersCount') or 0, reverse=True))))
    for group in order:
        items = sorted(grouped[group], key=lambda x: x.get('stargazersCount') or 0, reverse=True)
        sections.append('<h2 class="grp" data-cat="%s">%s <span class="n">%d</span></h2><div class="grid">%s</div>'
                        % (esc(group), esc(group), len(items), ''.join(card(r, args.owner) for r in items)))

    html_page = f'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(args.title)}</title>
<style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  body {{ font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','PingFang SC','Microsoft YaHei',sans-serif;
          background:#f8fafc; color:#0f172a; }}
  header {{ background:linear-gradient(135deg,#0f172a,#1e3a5f); color:#fff; padding:40px 24px; }}
  header h1 {{ font-size:24px; }}
  header p {{ color:#94a3b8; font-size:13px; margin-top:8px; }}
  .wrap {{ max-width:1080px; margin:0 auto; padding:0 24px; }}
  input[type=search] {{ width:100%; margin:20px 0 8px; padding:10px 14px; border-radius:10px;
          border:1px solid #cbd5e1; font-size:14px; background:#fff; }}
  .cats {{ display:flex; gap:8px; flex-wrap:wrap; margin-bottom:16px; }}
  .cats button {{ padding:5px 12px; border-radius:999px; border:1px solid #cbd5e1; background:#fff;
          font-size:12px; cursor:pointer; color:#475569; }}
  .cats button.on {{ background:#f97316; color:#fff; border-color:#f97316; }}
  h2.grp {{ font-size:16px; margin:28px 0 12px; }}
  h2.grp .n {{ color:#94a3b8; font-size:12px; }}
  h2.feat-h {{ color:#ea580c; }}
  .grid {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(300px,1fr)); gap:12px; }}
  .grid[data-g="feat"] .card {{ border-color:#fdba74; background:linear-gradient(180deg,#fff7ed,#fff); }}
  .grid[data-g="feat"] .card:hover {{ border-color:#f97316; }}
  .card {{ display:block; background:#fff; border:1px solid #e2e8f0; border-radius:12px; padding:14px;
          text-decoration:none; color:inherit; transition:.15s; }}
  .card:hover {{ transform:translateY(-2px); box-shadow:0 8px 24px rgba(15,23,42,.08); border-color:#f97316; }}
  .head {{ display:flex; justify-content:space-between; align-items:center; gap:8px; }}
  .name {{ font-weight:600; font-size:14px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }}
  .b {{ font-size:10px; padding:2px 6px; border-radius:999px; flex-shrink:0; }}
  .b.fork {{ background:#f1f5f9; color:#64748b; }}
  .b.arc {{ background:#fef2f2; color:#ef4444; }}
  .desc {{ color:#64748b; font-size:12.5px; margin:8px 0; line-height:1.5;
          display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical; overflow:hidden; }}
  .meta {{ display:flex; align-items:center; gap:10px; color:#94a3b8; font-size:11.5px; }}
  .lang {{ display:flex; align-items:center; gap:5px; }}
  .lang i {{ width:10px; height:10px; border-radius:50%; }}
  .stars {{ color:#f97316; }}
  .time {{ margin-left:auto; }}
  footer {{ text-align:center; color:#94a3b8; font-size:12px; padding:32px 0; }}
</style></head><body>
<header><div class="wrap">
  <h1>🗂️ {esc(args.title)}</h1>
  <p>{esc(args.owner) if args.owner else ''} · 共 {total} 个仓库 · 由 project-hub 生成</p>
</div></header>
<div class="wrap">
  <input type="search" id="q" placeholder="搜索仓库名 / 描述...">
  <div class="cats" id="cats"><button class="on" data-cat="">全部</button></div>
  {"".join(sections)}
</div>
<footer>Generated by <a href="https://github.com/holtwood/my-agent-skills">my-agent-skills/project-hub</a></footer>
<script>
  const cats = [...new Set([...document.querySelectorAll('h2.grp')].map(h => h.dataset.cat))];
  const btnBox = document.getElementById('cats');
  const allBtn = btnBox.querySelector('button');
  allBtn.onclick = () => {{
    document.querySelectorAll('#cats button').forEach(x => x.classList.remove('on'));
    allBtn.classList.add('on'); apply();
  }};
  cats.forEach(c => {{ const b = document.createElement('button'); b.textContent = c; b.dataset.cat = c;
    b.onclick = () => {{ document.querySelectorAll('#cats button').forEach(x => x.classList.remove('on'));
      b.classList.add('on'); apply(); }}; btnBox.appendChild(b); }});
  const q = document.getElementById('q');
  function apply() {{
    const cat = document.querySelector('#cats button.on')?.dataset.cat || '';
    const kw = q.value.trim().toLowerCase();
    document.querySelectorAll('.card').forEach(el => {{
      const inCat = !cat || el.closest('.grid').previousElementSibling.dataset.cat === cat;
      const hitKw = !kw || el.textContent.toLowerCase().includes(kw);
      el.style.display = inCat && hitKw ? '' : 'none';
    }});
    document.querySelectorAll('h2.grp').forEach(h => {{
      const visible = [...h.nextElementSibling.querySelectorAll('.card')].some(c => c.style.display !== 'none');
      h.style.display = visible ? '' : 'none';
      h.nextElementSibling.style.display = visible ? '' : 'none';
    }});
  }}
  q.oninput = apply;
</script>
</body></html>'''

    import os
    os.makedirs(os.path.dirname(os.path.abspath(args.out_html)), exist_ok=True)
    with open(args.out_html, 'w', encoding='utf-8') as f:
        f.write(html_page)
    print(f'✅ 已生成 {args.out_html}（{total} 个仓库，{len(order) + (1 if featured else 0)} 个分区，精选 {len(featured)} 个）')

if __name__ == '__main__':
    main()
