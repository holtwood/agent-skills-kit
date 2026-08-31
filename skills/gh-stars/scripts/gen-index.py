#!/usr/bin/env python3
"""
gh-stars — 把 Star 列表生成自包含静态索引页（Python 标准库，零依赖）

用法:
  gen-index.py <stars.json> <out.html> [--desc-zh desc_zh.json] [--title 标题] [--owner 用户名]
"""
import argparse
import html
import json

def esc(s):
    return html.escape(str(s) if s is not None else '', quote=True)

def load_desc(path):
    if not path:
        return {}
    try:
        with open(path, encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('stars_json')
    ap.add_argument('out_html')
    ap.add_argument('--desc-zh')
    ap.add_argument('--title', default='我的 GitHub 收藏')
    ap.add_argument('--owner', default='')
    args = ap.parse_args()

    with open(args.stars_json, encoding='utf-8') as f:
        try:
            stars = json.load(f)
        except json.JSONDecodeError:
            # gh api --jq '.[]' 输出 JSONL（每行一个对象），例如 page-stars 的数据格式
            f.seek(0)
            stars = [json.loads(line) for line in f if line.strip()]

    desc_zh = load_desc(args.desc_zh)

    def category(repo):
        topics = repo.get('topics') or []
        lang = repo.get('language') or '其他'
        if repo.get('fork'):
            return 'Fork'
        for t in topics:
            if t in {'awesome-list', 'awesome', 'awesome-list-zh', 'resources', 'reading-list'}:
                return 'Awesome 合集'
            if t in {'javascript', 'typescript', 'python', 'go', 'rust'}:
                return '开发工具'
            if t in {'machine-learning', 'ai', 'llm', 'agent', 'deep-learning'}:
                return 'AI / 大模型'
        mapping = {
            'JavaScript': '前端', 'TypeScript': '前端', 'Vue': '前端', 'React': '前端',
            'Python': '后端/Python', 'Go': '后端/Go', 'Rust': '后端/Rust',
            'Shell': '脚本工具', 'C': '底层', 'C++': '底层',
        }
        return mapping.get(lang, '其他')

    grouped = {}
    for s in stars:
        repo = s if 'full_name' in s else s.get('repo', s)
        repo = dict(repo)
        repo['starred_at'] = s.get('starred_at', '')
        repo['_category'] = category(repo)
        if desc_zh and repo.get('full_name') in desc_zh:
            repo['description'] = desc_zh[repo['full_name']]
        grouped.setdefault(repo['_category'], []).append(repo)

    order = sorted(grouped.keys())
    total = len(stars)

    cards = []
    for cat in order:
        items = grouped[cat]
        cards.append(f'<h2 class="cat" id="{esc(cat)}">{esc(cat)} <span class="n">{len(items)}</span></h2>')
        cards.append('<div class="grid">')
        for r in sorted(items, key=lambda x: x.get('stargazers_count') or 0, reverse=True):
            name = r['full_name']
            desc = r.get('description') or '（无描述）'
            lang = r.get('language') or ''
            stars_cnt = r.get('stargazers_count') or 0
            star_date = (r.get('starred_at') or '')[:10]
            cards.append(f'''<a class="card" href="{esc(r['html_url'])}" target="_blank" rel="noopener">
  <div class="head">
    <span class="name">{esc(name)}</span>
    <span class="stars">★ {stars_cnt:,}</span>
  </div>
  <p class="desc">{esc(desc)}</p>
  <div class="meta"><span>{esc(lang)}</span><span>{star_date}</span></div>
</a>''')
        cards.append('</div>')

    html_page = f'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(args.title)}</title>
<style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  body {{ font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','PingFang SC','Microsoft YaHei',sans-serif;
          background:#f1f5f9; color:#0f172a; }}
  header {{ background:linear-gradient(135deg,#1e293b,#0f172a); color:#fff; padding:32px 24px; }}
  header h1 {{ font-size:22px; }}
  header p {{ color:#94a3b8; font-size:13px; margin-top:6px; }}
  .wrap {{ max-width:1080px; margin:0 auto; padding:0 24px; }}
  input[type=search] {{ width:100%; margin:20px 0 8px; padding:10px 14px; border-radius:10px;
          border:1px solid #cbd5e1; font-size:14px; background:#fff; }}
  .cats {{ display:flex; gap:8px; flex-wrap:wrap; margin-bottom:16px; }}
  .cats button {{ padding:5px 12px; border-radius:999px; border:1px solid #cbd5e1; background:#fff;
          font-size:12px; cursor:pointer; color:#475569; }}
  .cats button.on {{ background:#f97316; color:#fff; border-color:#f97316; }}
  h2.cat {{ font-size:16px; margin:24px 0 12px; }}
  h2.cat .n {{ color:#94a3b8; font-size:12px; }}
  .grid {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(300px,1fr)); gap:12px; }}
  .card {{ display:block; background:#fff; border:1px solid #e2e8f0; border-radius:12px; padding:14px;
          text-decoration:none; color:inherit; transition:.15s; }}
  .card:hover {{ transform:translateY(-2px); box-shadow:0 8px 24px rgba(15,23,42,.08); border-color:#f97316; }}
  .head {{ display:flex; justify-content:space-between; align-items:center; gap:8px; }}
  .name {{ font-weight:600; font-size:14px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }}
  .stars {{ color:#f97316; font-size:12px; flex-shrink:0; }}
  .desc {{ color:#64748b; font-size:12.5px; margin:8px 0; line-height:1.5;
          display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical; overflow:hidden; }}
  .meta {{ display:flex; justify-content:space-between; color:#94a3b8; font-size:11.5px; }}
  footer {{ text-align:center; color:#94a3b8; font-size:12px; padding:32px 0; }}
</style></head><body>
<header><div class="wrap">
  <h1>⭐ {esc(args.title)}</h1>
  <p>{esc(args.owner) if args.owner else ''} · 共 {total} 个项目 · 由 gh-stars 生成</p>
</div></header>
<div class="wrap">
  <input type="search" id="q" placeholder="搜索项目名 / 描述...">
  <div class="cats" id="cats"><button class="on" data-cat="">全部</button></div>
  <div id="content">{"".join(cards)}</div>
</div>
<footer>Generated by <a href="https://github.com/holtwood/agent-skills-zh">agent-skills-zh/gh-stars</a></footer>
<script>
  const cats = [...new Set([...document.querySelectorAll('h2.cat')].map(h => h.textContent.split(' ')[0]))];
  const btnBox = document.getElementById('cats');
  cats.forEach(c => {{ const b = document.createElement('button'); b.textContent = c; b.dataset.cat = c;
    b.onclick = () => {{ document.querySelectorAll('#cats button').forEach(x => x.classList.remove('on'));
      b.classList.add('on'); apply(); }}; btnBox.appendChild(b); }});
  const q = document.getElementById('q');
  function apply() {{
    const cat = document.querySelector('#cats button.on')?.dataset.cat || '';
    const kw = q.value.trim().toLowerCase();
    document.querySelectorAll('h2.cat, .card').forEach(el => {{
      const show = el.classList.contains('card')
        ? (!cat || el.closest('.grid').previousElementSibling.textContent.startsWith(cat))
          && (!kw || el.textContent.toLowerCase().includes(kw))
        : true;
      el.style.display = show ? '' : 'none';
    }});
    document.querySelectorAll('h2.cat').forEach(h => {{
      const visible = [...h.nextElementSibling.querySelectorAll('.card')].some(c => c.style.display !== 'none');
      h.style.display = visible ? '' : 'none';
    }});
  }}
  q.oninput = apply;
</script>
</body></html>'''

    import os
    os.makedirs(os.path.dirname(os.path.abspath(args.out_html)), exist_ok=True)
    with open(args.out_html, 'w', encoding='utf-8') as f:
        f.write(html_page)
    print(f'✅ 已生成 {args.out_html}（{total} 个项目，{len(order)} 个分类）')

if __name__ == '__main__':
    main()