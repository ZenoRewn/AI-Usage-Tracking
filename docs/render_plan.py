#!/usr/bin/env python3
"""Render the planning documents as an offline HTML reading page.

Author: Zeno Ren
This is a small renderer for these documents, not application code.
"""

from pathlib import Path
import html
import re

ROOT = Path(__file__).resolve().parent


def inline(text):
    tokens = []

    def save(value):
        tokens.append(value)
        return f"\x00{len(tokens) - 1}\x00"

    text = re.sub(r"`([^`]+)`", lambda m: save("<code>" + html.escape(m[1]) + "</code>"), text)
    text = re.sub(
        r"\[([^\]]+)\]\(([^)]+)\)",
        lambda m: save('<a href="' + html.escape(m[2], quote=True) + '">' + html.escape(m[1]) + "</a>"),
        text,
    )
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"\x00(\d+)\x00", lambda m: tokens[int(m[1])], text)
    return text


DIAGRAM = '''<div class="architecture" role="img" aria-label="五个工具入口经适配器、去重和项目关联进入本机数据库；账户配额独立采集，最后由菜单栏与主窗口展示">
<div class="arch-label">LOCAL SOURCES · 五个入口</div>
<div class="sources">
<div><b>Codex App</b><small>本地记录 · RPC</small><span class="tag observed">观察到字段</span></div>
<div><b>Claude Code</b><small>JSONL · statusLine</small><span class="tag observed">观察到字段</span></div>
<div><b>Copilot VS Code</b><small>OTel 文件</small><span class="tag official">官方文档支持</span></div>
<div><b>Copilot CLI</b><small>OTel 文件</small><span class="tag official">官方文档支持</span></div>
<div class="uncertain"><b>Copilot App</b><small>出口与项目归属</small><span class="tag pending">P0 待验证</span></div>
</div>
<div class="arrow">↓</div>
<div class="layer">来源适配器 <small>版本探测 / 权限 / 增量游标</small></div>
<div class="arrow">↓</div>
<div class="layer accent">白名单提取 → 事件去重 → 计量归一 → 项目关联</div>
<div class="arrow">↓</div>
<div class="storage"><div>本机 SQLite <small>规范化流水 · 事务与索引</small></div><div>账户快照 <small>独立采集 · 单位与周期 · 新鲜度</small></div></div>
<div class="arrow">↓</div>
<div class="layer">聚合查询 · 版本化估价 · 数据质量 · 通知规则</div>
<div class="arrow">↓</div>
<div class="outputs"><div>菜单栏<small>额度与重置</small></div><div>SwiftUI 主窗口<small>项目 / 会话 / 趋势 / 导出</small></div></div>
<p class="diagram-note">架构规划图 · 箭头表示拟议数据流，不代表已完成集成。Author: Zeno Ren</p>
</div>'''


def render(text):
    lines = text.splitlines()
    out = []
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            i += 1
            continue
        if line.startswith("```"):
            language = line[3:]
            block = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                block.append(lines[i])
                i += 1
            out.append(DIAGRAM if language == "mermaid" else "<pre><code>" + html.escape("\n".join(block)) + "</code></pre>")
        elif line.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                if not all(re.fullmatch(r":?-+:?", c) for c in cells):
                    rows.append(cells)
                i += 1
            out.append('<div class="table-wrap"><table><thead><tr>' + "".join("<th>" + inline(c) + "</th>" for c in rows[0]) + "</tr></thead><tbody>")
            for row in rows[1:]:
                out.append("<tr>" + "".join("<td>" + inline(c) + "</td>" for c in row) + "</tr>")
            out.append("</tbody></table></div>")
            continue
        elif re.match(r"^#{1,6} ", line):
            level = len(line.split(" ")[0])
            out.append(f"<h{level}>" + inline(line[level + 1:]) + f"</h{level}>")
        elif line.startswith("- ") or re.match(r"^\d+\. ", line):
            ordered = not line.startswith("- ")
            pattern = r"^\d+\. " if ordered else r"^- "
            tag = "ol" if ordered else "ul"
            out.append("<" + tag + ">")
            while i < len(lines) and re.match(pattern, lines[i].strip()):
                out.append("<li>" + inline(re.sub(pattern, "", lines[i].strip())) + "</li>")
                i += 1
            out.append("</" + tag + ">")
            continue
        else:
            out.append("<p>" + inline(line) + "</p>")
        i += 1
    return "\n".join(out)


plan = (ROOT / "SYSTEM_PLAN.md").read_text()
parts = re.split(r"(?m)^## ", plan)[1:]
nav = []
sections = []
for n, part in enumerate(parts, 1):
    title, _, body = part.partition("\n")
    section_id = f"section-{n}"
    nav.append(f'<a href="#{section_id}"><span>{n:02}</span>{inline(re.sub(r"^\d+\. ", "", title))}</a>')
    sections.append(f'<section id="{section_id}"><h2>{inline(title)}</h2>{render(body)}</section>')

evidence = render((ROOT / "RESEARCH_EVIDENCE.md").read_text())
css = '''
:root{--ink:#142b36;--muted:#657680;--green:#087d74;--line:#dde5e7;--paper:#fff;--bg:#f3f6f6}
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:30px}body{margin:0;min-width:1120px;color:var(--ink);background:var(--bg);font-family:-apple-system,BlinkMacSystemFont,"PingFang SC","Hiragino Sans GB",sans-serif;font-size:15px;line-height:1.8}a{color:var(--green);text-decoration:none}a:hover{text-decoration:underline}button{font:inherit;cursor:pointer}.sidebar{position:fixed;left:0;top:0;bottom:0;width:230px;border-right:1px solid var(--line);background:#fff;padding:30px 20px;overflow:auto}.brand{font-weight:750;font-size:19px;letter-spacing:-.4px}.brand-mark{display:inline-block;background:var(--green);color:white;border-radius:7px;width:29px;height:29px;text-align:center;line-height:29px;margin-right:9px}.sidebar .sub{color:var(--muted);font-size:12px;margin:9px 0 29px}.sidebar nav a{display:flex;gap:10px;padding:9px 8px;color:#526671;font-size:13px;border-radius:6px;line-height:1.5;margin-bottom:3px}.sidebar nav a span{color:#9ba9af;font-size:11px;padding-top:2px;min-width:18px}.sidebar nav a.active{background:#e9f5f2;color:#087166;font-weight:650}.sidebar footer{font-size:11px;color:var(--muted);margin-top:26px;border-top:1px solid var(--line);padding-top:18px}main{margin-left:230px;padding:34px 42px 80px;max-width:1620px}.topline{display:flex;justify-content:space-between;align-items:center;font-size:12px;color:var(--muted);letter-spacing:.4px;margin-bottom:18px}.actions{display:flex;gap:16px;align-items:center}.actions button{padding:5px 14px;border:1px solid var(--line);border-radius:6px;background:white;color:var(--ink);font-size:12px}.hero{padding:34px 40px;background:#102f39;border-radius:16px;color:#fff;position:relative;overflow:hidden}.hero .eyebrow{font-size:11px;letter-spacing:2px;color:#7ed9c6;font-weight:700}.hero h1{font-size:38px;line-height:1.3;letter-spacing:-1.2px;margin:16px 0}.hero p{max-width:800px;color:#c6d6dc;font-size:15px;margin:0 0 19px}.hero .pills{display:flex;gap:8px}.hero .pills span{border:1px solid #43606a;color:#cce4e6;font-size:11px;padding:4px 11px;border-radius:20px}.metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin:18px 0}.metric{background:white;border:1px solid var(--line);border-radius:11px;padding:17px 20px}.metric b{display:block;font-size:23px;letter-spacing:-.5px}.metric span{font-size:12px;color:var(--muted)}.decision{background:#e7f3ef;border-left:4px solid #20957c;border-radius:0 8px 8px 0;padding:17px 22px;margin:18px 0 28px;font-size:14px}.decision b{color:#006958}section{background:white;border:1px solid var(--line);border-radius:12px;padding:29px 32px;margin-bottom:22px;scroll-margin-top:26px}h2{font-size:24px;letter-spacing:-.5px;margin:0 0 22px;padding-bottom:14px;border-bottom:1px solid var(--line);line-height:1.45}h3{font-size:18px;line-height:1.5;margin:27px 0 12px}p{margin:12px 0}ul,ol{padding-left:24px;margin:12px 0}li{margin-bottom:9px;padding-left:3px}strong{font-weight:650;color:#102f39}code{font-family:ui-monospace,SFMono-Regular,monospace;font-size:.86em;background:#f0f4f5;padding:2px 5px;border-radius:4px;overflow-wrap:anywhere}pre{background:#142e39;color:#e0eff0;padding:20px;overflow:auto;border-radius:8px}pre code{padding:0;background:none;color:inherit}.table-wrap{overflow-x:auto;margin:18px 0 23px;border:1px solid var(--line);border-radius:8px}table{border-collapse:collapse;width:100%;font-size:13px;line-height:1.75}th{text-align:left;color:#365560;background:#f1f6f5;font-weight:650;padding:13px 15px;border-bottom:1px solid var(--line)}td{padding:13px 15px;border-bottom:1px solid #e8eef0;vertical-align:top;min-width:112px;overflow-wrap:anywhere}tr:last-child td{border-bottom:0}td:first-child{font-weight:600;color:#294955}tbody tr:nth-child(even){background:#fbfcfc}.architecture{border:1px solid #d8e6e5;background:#f7fbfa;padding:24px;border-radius:10px;margin:20px 0}.arch-label{font-size:10px;letter-spacing:1.8px;color:#698581;margin-bottom:14px}.sources{display:grid;grid-template-columns:repeat(5,1fr);gap:8px}.sources>div{padding:13px 7px;background:white;border:1px solid #d6e5e2;border-radius:8px;text-align:center;font-size:12px}.sources b{font-size:12px}.architecture small{display:block;color:var(--muted);font-size:11px;line-height:1.6;font-weight:400;margin-top:4px}.tag{display:inline-block;font-size:9px;padding:1px 6px;border-radius:10px;margin-top:8px;white-space:nowrap}.observed{background:#e1f3e9;color:#216848}.official{background:#e6edf9;color:#46669b}.pending{background:#fff1d7;color:#976515}.sources .uncertain{border-style:dashed;border-color:#d9b76d}.arrow{text-align:center;color:#75a197;line-height:1.3;font-size:22px;margin:5px 0}.layer{border:1px solid #d2e3de;background:#fff;border-radius:7px;text-align:center;padding:12px;font-size:13px}.layer small{display:inline;margin-left:10px}.layer.accent{background:#e5f3ee;color:#196d5f;font-weight:600}.storage{display:grid;grid-template-columns:1.5fr 1fr;gap:12px}.storage>div{border-radius:7px;border:1px solid #b1cec5;background:white;text-align:center;padding:15px;font-size:14px;font-weight:650}.outputs{display:grid;grid-template-columns:1fr 2fr;gap:12px}.outputs>div{background:#163d47;color:white;border-radius:7px;padding:12px;text-align:center;font-size:14px}.outputs small{color:#bbd4d7}.diagram-note{font-size:10px;color:var(--muted);text-align:center;margin:17px 0 0}details{background:#fff;border:1px solid var(--line);border-radius:12px;margin-top:25px;padding:24px 32px}summary{cursor:pointer;font-weight:650;font-size:18px}details h1{font-size:27px}.endnote{font-size:12px;color:var(--muted);text-align:center;margin-top:32px}.source-caption{font-size:12px;color:var(--muted);margin-bottom:22px}
@media print{body{min-width:0;background:white;font-size:10pt}.sidebar,.topline,.actions{display:none}main{margin:0;padding:0;max-width:none}.hero{color:#142b36;background:#eef5f4;padding:25px}.hero p,.hero .eyebrow{color:#365560}.hero .pills span{color:#365560}.hero h1{font-size:28px}.metrics{gap:8px}.metric{padding:10px}section{padding:14px;border:0;border-radius:0;break-inside:auto;margin:0}h2,h3{break-after:avoid}.table-wrap{overflow:visible}thead{display:table-header-group}tr{break-inside:avoid}table{font-size:8pt}td,th{padding:7px;min-width:0}.architecture{break-inside:avoid}.tag{white-space:normal}a{color:#142b36}details{border:0;padding:0}.endnote{margin-top:20px}}
'''
page = '''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="author" content="Zeno Ren"><meta name="description" content="个人单机 macOS AI 工具用量监控：系统分析、功能与实施规划"><title>Usage Tracking · 系统规划 | Zeno Ren</title><style>''' + css + '''</style></head><body>
<aside class="sidebar"><div class="brand"><span class="brand-mark">M</span>Usage Tracking</div><div class="sub">MAC NATIVE · LOCAL FIRST<br>系统分析与功能规划 / v0.1</div><nav>''' + "".join(nav) + '''<a href="#evidence"><span>↗</span>研究证据与源码</a></nav><footer>2026.09.09<br>Author: Zeno Ren<br>构建前规划 · 现状见 README</footer></aside>
<main><div class="topline"><span>DESIGN BRIEF / 2026.09.09</span><div class="actions"><a href="SYSTEM_PLAN.md">设计源文档</a><a href="RESEARCH_EVIDENCE.md">证据源文档</a><button id="print">打印方案</button></div></div>
<header class="hero"><div class="eyebrow">PERSONAL AI USAGE OBSERVATORY</div><h1>看清额度，更看清每个项目的投入。</h1><p>将 Codex App、Claude Code CLI 与 GitHub Copilot 的多个入口，整理为可核对的本地用量记录。以真实数据覆盖决定能力承诺。</p><div class="pills"><span>SwiftUI + AppKit</span><span>个人单机 · 数据本地保存</span><span>Token / 配额 / 成本 / 账单独立计量</span></div></header>
<div class="metrics"><div class="metric"><b>3 个工具</b><span>Codex · Claude Code · Copilot</span></div><div class="metric"><b>5 个入口</b><span>App / CLI / VS Code 分别验证</span></div><div class="metric"><b>4 类计量</b><span>消耗 · 额度 · 估价 · 实扣</span></div><div class="metric"><b>本地优先</b><span>文件采集 + 本机 SQLite</span></div></div>
<div class="decision"><b>建议：独立原生 App，选择性复用成熟实现。</b><br>菜单栏查看账户额度，主窗口分析跨工具项目。先验证 Copilot App 数据出口、去重与归属，再承诺五入口完整支持。</div>
<p class="source-caption">本页保留初始规划；Usage Tracking 0.1 已实现可运行 App。当前已实现能力与限制，请以项目 README 和构建记录为准。</p>
''' + "\n".join(sections) + '''<details id="evidence"><summary>展开研究证据、固定提交与本机核验边界</summary>''' + evidence + '''</details><footer class="endnote">Author: Zeno Ren · 2026-09-09 · 离线阅读页，无外部脚本、字体或分析追踪。</footer></main>
<script>
document.getElementById('print').addEventListener('click',()=>window.print());
document.querySelector('a[href="#evidence"]').addEventListener('click',()=>{document.getElementById('evidence').open=true;});
const links=[...document.querySelectorAll('nav a')];
const observer=new IntersectionObserver(entries=>{for(const e of entries){if(e.isIntersecting){links.forEach(a=>a.classList.toggle('active',a.hash==='#'+e.target.id));}}},{rootMargin:'-5% 0px -70% 0px',threshold:0});
document.querySelectorAll('main section').forEach(s=>observer.observe(s));
</script></body></html>'''
(ROOT / "PLAN.html").write_text(page)
print(f"Rendered {len(sections)} sections and evidence appendix to {ROOT / 'PLAN.html'}")
