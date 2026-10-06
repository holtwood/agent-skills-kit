#!/usr/bin/env python3
"""prose_lint.py — 中文文章文风指纹检查（复查线索，不是判决）。

用法:
    python3 prose_lint.py <article.md> [--dict 词表文件] [--strict] [--json]

检查项:
  1. 指纹词表：铺垫句式（这里有个/有个坑）、段末信号词（这说明/由此可见）、翻译腔
     （不难发现/至关重要/不容忽视）、万能动词（进行了研究）、互联网黑话（赋能/抓手/闭环）、
     客套升华（拭目以待/未来可期）、AI 元话语泄漏（作为AI/截至我的知识/训练数据）、
     前景套话（尽管X有其意义…面临的挑战）。--dict 可追加自定义词表，每行一条。
  2. 虚胖量化：整句含「大幅/显著/明显」等量化词但无任何数字（含中文数字）。
  3. 抽象名词化：全文「X性」词 ≥4 处（JCSA 2026 中文实证：稳定性/适用性式名词化）。
  4. 过渡词堆叠：句首「此外/因此/同时/然而」式书面过渡 ≥3 处。
  5. 地区词与简繁：简体稿混入台湾科技词（伺服器/介面/记忆体）或散落繁体字。
  6. 句首复读：相邻句共享 ≥3 字前缀的连续 3 句以上。
  7. 句长方差（burstiness）：报告句长均值与变异系数 CV。真人 CV≈0.45，AI 稿常 <0.38；
     <0.28 提示节奏过平（需 ≥10 句才检查，仅参考不单独判失败）。

原则: 命中词表是复查线索——「闭环控制」「进行了实验」在真实语境可以完全正常，
      由人判断去留。默认只报告；--strict 时任何指纹命中使退出码为 1。

退出码: 0 通过/仅提示 / 1 --strict 下有命中 / 2 参数或文件错误
"""
import argparse
import json
import re
import sys

# (正则, 类别, 建议)
FINGERPRINTS = [
    (r"这里有个|有个(经典)?(坑|细节|原则|问题)", "铺垫句式", "直接陈述，删掉铺垫壳"),
    (r"这说明|由此可见|可以看出|通过以上分析|综上所述|总而言之", "段末信号词", "删掉不损失信息就删"),
    (r"值得注意的是|不难发现|众所周知|毋庸置疑|本文将|作为一个|至关重要|不容忽视|发挥了?重要作用|扮演了?重要角色", "翻译腔", "换口语或直接说结论"),
    (r"进行了[^，。；]{1,8}(分析|研究|测试|验证|讨论|探索)", "万能动词", "换实动词：分析了/研究了"),
    (r"赋能|抓手|闭环|拉通|对齐|沉淀|打通|协同|联动|洞察|赛道|心智|调性|势能|颗粒度", "互联网黑话", "换成具体动作或删掉"),
    (r"拭目以待|未来可期|一起加油|愿我们", "客套升华", "删掉，不替作者写祝愿"),
    (r"作为(一个)?(AI|人工智能|语言模型)|截至我的|训练数据|知识截止|信息可能不完整|仅供参考", "AI 元话语", "AI 自我介绍/免责声明漏进正文，删"),
    (r"尽管[^，。]{2,15}有其[^，。]{1,10}(意义|价值|优势)|面临的挑战[是有]", "前景套话", "「前景/挑战」式结尾章节，换成具体收尾"),
    (r"可不是写死的|也不是(一张)?死贴图|做起来比说起来(难|费劲|复杂)|还有一笔没人催的账|这笔(运算|账)也不便宜|这个选项我最后没敢开|为什么[？\?][ ]*因为", "伪老练口语", "直接陈述机制或决策，删掉自嘲套话"),
]
# 无数字量化词：整句出现模糊量化但没有任何数字（含中文数字），属于「虚胖主张」
VAGUE_QUANT = re.compile(r"大幅|显著|明显|极大|极多|大量|不少|众多|诸多|广泛|充分|深入")
HAS_NUMBER = re.compile(r"[0-9０-９一二三四五六七八九十百千万亿两半数]+")
# 「X性」抽象名词密度：中文实证（JCSA 2026）显示 AI 中文偏好「稳定性/适用性/依赖性」式名词化
XING_NOUN = re.compile(r"[一-龥]{2,4}性")
XING_NOUN_MIN = 4  # 全文 ≥4 处才报密度提示，单处属于正常术语
# 书面过渡词堆叠：句首「此外/进一步/同时/因此/然而/与此同时」连用是 AI 中文常见节奏
CONNECTOR = re.compile(r"^(此外|进一步|同时|因此|然而|与此同时|总的来说|另外|并且)")
CONNECTOR_MIN = 3
# 简繁与地区词检查（目标读者为大陆简体）：台湾科技词出现在简体稿=繁简混用破绽
# 注意「程式」排除「程式化/程序」语境；简繁转换只转字形不转词汇（OpenCC 同理）
REGION_WORDS = re.compile(r"伺服器|介面|记忆体|随身碟|萤幕|滑鼠|印表机|智慧型|物件导向|韧体|程式(?!化|序)")
# 简体稿中混入的高频繁体字（只收简中不存在的字形，「软体/阵列」属合法简中词不收）
TRAD_ONLY = re.compile(r"[體學習個們這為與說讀寫網開發時點擊當後經將麼資訊數據軟設計頁讓還過關問題辦錄觀標題檔記憶沒實]")
TRAD_MIN = 2
SENT_SPLIT = re.compile(r"(?<=[。！？!?…])")
OPENER_PREFIX = 3
OPENER_RUN = 3
CV_MIN_SENTS = 10


def _prefix_len(a: str, b: str) -> int:
    n = min(len(a), len(b))
    i = 0
    while i < n and a[i] == b[i]:
        i += 1
    return i


def body_lines(text: str) -> list:
    """只保留正文行：去标题、图片、代码块、frontmatter。"""
    out, in_code = [], False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("```"):
            in_code = not in_code
            continue
        if in_code or not s or s.startswith("#") or s.startswith("!"):
            continue
        s = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", s)
        s = re.sub(r"\[[^\]]*\]\([^)]*\)", lambda m: m.group(0)[1:m.group(0).index("]")], s)
        s = re.sub(r"[*`>]", "", s).strip()
        if s:
            out.append(s)
    return out


def sentences(lines: list) -> list:
    sents = []
    for line in lines:
        for part in SENT_SPLIT.split(line):
            part = part.strip()
            if part:
                sents.append(part)
    return sents


def lint(path: str, extra_patterns: list) -> dict:
    text = open(path, encoding="utf-8").read()
    lines = body_lines(text)
    sents = sentences(lines)
    joined = "\n".join(lines)

    findings = []
    for pat, cat, hint in FINGERPRINTS + extra_patterns:
        for m in re.finditer(pat, joined):
            line_no = joined[: m.start()].count("\n") + 1
            findings.append({"kind": "fingerprint", "cat": cat,
                             "text": m.group(0), "line": line_no, "hint": hint})

    for i, s in enumerate(sents):
        if VAGUE_QUANT.search(s) and not HAS_NUMBER.search(s):
            findings.append({"kind": "vague-quant", "cat": "虚胖量化",
                             "text": s[:24], "line": i + 1,
                             "hint": "量化主张没带数字，补依据或改弱表述"})

    xing = XING_NOUN.findall(joined)
    if len(xing) >= XING_NOUN_MIN:
        findings.append({"kind": "xing-noun", "cat": "抽象名词化",
                         "text": "、".join(xing[:6]), "line": 0,
                         "hint": f"全文 {len(xing)} 处「X性」词，中文 AI 偏爱名词化，能换实词就换"})

    conn = sum(1 for s in sents if CONNECTOR.search(s))
    if conn >= CONNECTOR_MIN:
        findings.append({"kind": "connector", "cat": "过渡词堆叠",
                         "text": f"{conn} 处句首过渡词", "line": 0,
                         "hint": "「此外/因此/同时」式句首过渡连用是 AI 中文节奏，砍一半试试"})

    region = [m.group(0) for m in REGION_WORDS.finditer(joined)]
    if region:
        findings.append({"kind": "region-word", "cat": "地区词混用",
                         "text": "、".join(region[:6]), "line": 0,
                         "hint": "简体稿混入台湾科技词（软体/伺服器等），换大陆术语"})

    trad = TRAD_ONLY.findall(joined)
    if len(trad) >= TRAD_MIN:
        findings.append({"kind": "trad-char", "cat": "简繁混用",
                         "text": "".join(trad[:8]), "line": 0,
                         "hint": f"简体稿混入 {len(trad)} 个繁体字，逐字核对"})

    run_start = 0
    for i in range(1, len(sents) + 1):
        same = i < len(sents) and _prefix_len(sents[i - 1], sents[i]) >= OPENER_PREFIX
        if not same:
            if i - run_start >= OPENER_RUN:
                findings.append({"kind": "opener-run", "cat": "句首复读",
                                 "text": sents[run_start][:OPENER_PREFIX + 2],
                                 "line": run_start + 1,
                                 "hint": f"连续 {OPENER_RUN}+ 句同开头，考虑变句式"})
            run_start = i

    lens = [len(re.sub(r"[\s「」『』“”‘’（）()《》，、；：—…·,.;:\-]", "", s)) for s in sents]
    stats = {}
    if lens:
        mean = sum(lens) / len(lens)
        var = sum((x - mean) ** 2 for x in lens) / len(lens)
        cv = (var ** 0.5 / mean) if mean else 0
        stats = {"sentences": len(lens), "mean_len": round(mean, 1),
                 "cv": round(cv, 3), "cv_hint": "真人≈0.45 / AI 常<0.38 / <0.28 偏平"}
        if cv < 0.28 and len(lens) >= CV_MIN_SENTS:
            findings.append({"kind": "burstiness", "cat": "句长过平",
                             "text": f"CV={cv:.2f}", "line": 0,
                             "hint": "长短句错落才是真人节奏，看是否有意保留短句"})
    return {"file": path, "stats": stats, "findings": findings}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("article", help="article.md 路径")
    ap.add_argument("--dict", dest="dictfile", help="追加词表文件，每行: 正则[TAB或空格]类别[TAB或空格]建议（类别/建议可省）")
    ap.add_argument("--strict", action="store_true", help="有指纹命中即退出码 1")
    ap.add_argument("--json", action="store_true", help="JSON 输出")
    args = ap.parse_args()

    extra = []
    if args.dictfile:
        for raw in open(args.dictfile, encoding="utf-8"):
            raw = raw.strip()
            if not raw or raw.startswith("#"):
                continue
            parts = re.split(r"[\t  ]{2,}|\t", raw)
            pat = parts[0]
            cat = parts[1] if len(parts) > 1 else "自定义词表"
            hint = parts[2] if len(parts) > 2 else "复查"
            extra.append((pat, cat, hint))

    try:
        report = lint(args.article, extra)
    except OSError as e:
        print(f"✗ 读取失败: {e}", file=sys.stderr)
        return 2

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=1))
    else:
        st = report["stats"]
        if st:
            print(f"句长统计: {st['sentences']} 句 / 均值 {st['mean_len']} 字 / CV {st['cv']}（{st['cv_hint']}）")
        if not report["findings"]:
            print("✅ 无文风指纹命中")
        for f in report["findings"]:
            loc = f"L{f['line']}" if f["line"] else "-"
            print(f"[{f['cat']}] {loc} 「{f['text']}」→ {f['hint']}")
        print(f"共 {len(report['findings'])} 条复查线索{'（strict 模式判失败）' if args.strict and report['findings'] else ''}")

    if args.strict and report["findings"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
