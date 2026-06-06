#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./generate_terminology_html.sh path/to/terminology_combined_with_images.csv
#   ./generate_terminology_html.sh path/to/terminology_combined_with_images.csv output/index.html
#
# Required CSV columns:
#   Category, Name, Japanese, Meaning
#
# Optional CSV columns:
#   URL, URL 1, URL 2
#   Image, Image 1, Image 2
#
# Notes:
# - Meaning is used as the English explanation.
# - Japanese is used as the Japanese explanation.
# - The generated HTML is a single file that can be published on GitHub Pages.

CSV_PATH="${1:-}"
OUTPUT_PATH="${2:-index.html}"

if [[ -z "$CSV_PATH" ]]; then
  echo "Usage: $0 path/to/terminology_master.csv [output.html]" >&2
  exit 1
fi

if [[ ! -f "$CSV_PATH" ]]; then
  echo "CSV not found: $CSV_PATH" >&2
  exit 1
fi

python3 - "$CSV_PATH" "$OUTPUT_PATH" <<'PY'
import csv
import json
import re
import sys
from collections import OrderedDict
from pathlib import Path

CATEGORY_ORDER = [
    "Attack Philosophy",
    "Phase Attack",
    "Passing",
    "Transition Attack",
    "Breakdown",
    "Phase Defence",
    "Defence",
    "Tackle",
    "Contest",
    "Scrum",
    "Lineout",
    "Maul",
    "Kicking",
    "Dummy Kick & Kick Receive",
    "Kick Sprint",
    "Restarts",
    "Restart",
]

def category_order_index(category):
    try:
        return CATEGORY_ORDER.index(category)
    except ValueError:
        return 999


csv_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

def clean(value):
    return (value or "").strip()

def normalize_name(value):
    return re.sub(r"\s+", "", str(value or "").strip().lower())

def get_first(row, columns):
    for col in columns:
        if col in row and clean(row.get(col)):
            return clean(row.get(col))
    return ""

def get_all(row, columns):
    values = []
    for col in columns:
        value = clean(row.get(col, ""))
        if value:
            values.append(value)
    return list(dict.fromkeys(values))

with csv_path.open("r", encoding="utf-8-sig", newline="") as f:
    reader = csv.DictReader(f)
    rows = list(reader)
    headers = reader.fieldnames or []

required = ["Category", "Name"]
missing = [col for col in required if col not in headers]
if missing:
    raise SystemExit(f"Missing required columns: {', '.join(missing)}")

records = OrderedDict()

for row in rows:
    category = clean(row.get("Category"))
    name = clean(row.get("Name"))
    japanese = get_first(row, ["Japanese", "JP", "日本語"])
    english = get_first(row, ["Meaning", "English", "EN"])
    urls = get_all(row, ["URL", "URL 1", "URL 2", "URL 3", "Video", "Video 1", "Video 2"])
    images = get_all(row, ["Image", "Image 1", "Image 2", "Image 3"])

    if not category or not name:
        continue

    item = {
        "category": category,
        "name": name,
        "english": english,
        "japanese": japanese,
        "urls": urls,
        "images": images,
    }

    key = (
        normalize_name(category),
        normalize_name(name),
        english.lower(),
        japanese.lower(),
        tuple(urls),
        tuple(images),
    )
    records[key] = item

plays = list(records.values())

indexed_plays = list(enumerate(plays))
indexed_plays.sort(key=lambda pair: (category_order_index(pair[1]["category"]), pair[0]))
plays = [item for _, item in indexed_plays]

category_counts = OrderedDict()
for item in plays:
    category_counts[item["category"]] = category_counts.get(item["category"], 0) + 1

default_palette = [
    ("#8c1530", "#f6e8ec", "#fbf4f6"),
    ("#a16207", "#f6eddc", "#fbf7ef"),
    ("#0f766e", "#def2ef", "#f1faf8"),
    ("#1d4ed8", "#e5edff", "#f4f7ff"),
    ("#c2410c", "#fae8dd", "#fdf4ee"),
    ("#7c3aed", "#eee6ff", "#f8f5ff"),
    ("#047857", "#e0f3eb", "#f2faf6"),
    ("#92400e", "#f4e8da", "#fbf6ef"),
    ("#0369a1", "#dff0fa", "#f2f9fd"),
    ("#be123c", "#fae2e9", "#fdf3f6"),
    ("#4338ca", "#e8e7fb", "#f5f5ff"),
    ("#334155", "#e7eaee", "#f5f6f8"),
    ("#b91c1c", "#fae3e3", "#fdf3f3"),
    ("#db2777", "#fbe2ef", "#fdf3f8"),
]

category_colors = {}
for index, category in enumerate(category_counts.keys()):
    accent, soft, pale = default_palette[index % len(default_palette)]
    category_colors[category] = {"accent": accent, "soft": soft, "pale": pale}

plays_json = json.dumps(plays, ensure_ascii=True, indent=2)
counts_json = json.dumps(category_counts, ensure_ascii=True, indent=2)
colors_json = json.dumps(category_colors, ensure_ascii=True, indent=2)

html = f"""<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Terminology</title>
  <style>
    :root {{
      --bg: #f7f2ec;
      --text: #161616;
      --muted: #6b6762;
      --line: rgba(125, 27, 43, .12);
      --accent: #8c1530;
      --gold: #c69a4b;
      --shadow: 0 18px 44px rgba(32, 18, 16, .10);
      --shadow-strong: 0 28px 60px rgba(59, 17, 22, .16);
    }}

    * {{ box-sizing: border-box; }}
    html, body {{
      width: 100%;
      max-width: 100%;
      overflow-x: hidden;
      position: relative;
    }}


    body {{
      margin: 0;
      min-height: 100vh;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans JP", Roboto, Helvetica, Arial, sans-serif;
      color: var(--text);
      background:
        radial-gradient(circle at top left, rgba(198,154,75,.16), transparent 28rem),
        radial-gradient(circle at top right, rgba(140,21,48,.14), transparent 24rem),
        linear-gradient(180deg, #f7f1eb 0%, #f8f5f1 100%);
    }}

    body::before {{
      content: "";
      position: fixed;
      inset: 0;
      pointer-events: none;
      opacity: .18;
      background-image:
        linear-gradient(90deg, rgba(255,255,255,.55) 1px, transparent 1px),
        linear-gradient(0deg, rgba(255,255,255,.38) 1px, transparent 1px);
      background-size: 28px 28px;
      mask-image: linear-gradient(180deg, rgba(0,0,0,.5), transparent 90%);
    }}

    .wrap {{
      width: min(1240px, calc(100% - 32px));
      margin: 0 auto;
    }}

    header {{
      padding: 34px 20px 18px;
    }}

    .hero {{
      position: relative;
      overflow: hidden;
      isolation: isolate;
      background: linear-gradient(135deg, rgba(104,0,22,.96) 0%, rgba(140,21,48,.94) 38%, rgba(25,18,19,.98) 100%);
      border: 1px solid rgba(255,255,255,.14);
      box-shadow: var(--shadow-strong);
      border-radius: 34px;
      padding: 32px;
      color: #fffaf6;
    }}

    .hero::before {{
      content: "";
      position: absolute;
      width: 320px;
      height: 320px;
      right: -80px;
      top: -90px;
      border-radius: 999px;
      background: radial-gradient(circle, rgba(198,154,75,.36) 0%, rgba(198,154,75,.06) 42%, transparent 72%);
      z-index: -1;
    }}

    .eyebrow {{
      display: inline-flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 12px;
      padding: 8px 14px;
      border-radius: 999px;
      border: 1px solid rgba(255,255,255,.18);
      background: rgba(255,255,255,.08);
      color: rgba(255,250,246,.88);
      font-size: 11px;
      font-weight: 800;
      letter-spacing: .22em;
      text-transform: uppercase;
      backdrop-filter: blur(8px);
    }}

    .eyebrow::before {{
      content: "";
      width: 8px;
      height: 8px;
      border-radius: 999px;
      background: linear-gradient(180deg, #fff4d3, var(--gold));
      box-shadow: 0 0 0 4px rgba(198,154,75,.14);
    }}

    h1 {{
      margin: 0;
      font-size: clamp(34px, 5.1vw, 58px);
      letter-spacing: -.05em;
      line-height: .98;
    }}

    .subtitle {{
      max-width: 760px;
      margin: 14px 0 0;
      color: rgba(255,250,246,.82);
      font-size: 15px;
      line-height: 1.8;
    }}

    .hero,
    .wrap,
    header,
    main {{
      max-width: 100%;
    }}

    .hero {{
      overflow-x: hidden;
    }}

    .controls {{
      margin-top: 22px;
      display: grid;
      grid-template-columns: 1fr auto;
      gap: 12px;
      align-items: center;
    }}

    .searchbox {{
      position: relative;
    }}

    .searchbox input {{
      width: 100%;
      border: 1px solid rgba(255,255,255,.14);
      background: rgba(255,255,255,.98);
      border-radius: 20px;
      padding: 18px 54px 18px 18px;
      font-size: 16px;
      outline: none;
      color: var(--text);
      box-shadow: inset 0 1px 0 rgba(255,255,255,.9), 0 10px 28px rgba(20,18,18,.10);
      transition: border-color .18s ease, box-shadow .18s ease, transform .18s ease;
    }}

    .searchbox input:focus {{
      border-color: rgba(198,154,75,.9);
      box-shadow: inset 0 1px 0 rgba(255,255,255,.9), 0 0 0 4px rgba(198,154,75,.18), 0 14px 28px rgba(20,18,18,.12);
      transform: translateY(-1px);
    }}

    .search-icon {{
      position: absolute;
      right: 16px;
      top: 50%;
      transform: translateY(-50%);
      color: var(--accent);
      font-size: 18px;
      pointer-events: none;
    }}

    .clear-btn {{
      border: 0;
      border-radius: 18px;
      padding: 15px 18px;
      background: linear-gradient(180deg, #fefaf3 0%, #f1e2bf 100%);
      color: #1d1d1f;
      font-weight: 800;
      font-size: 14px;
      cursor: pointer;
      box-shadow: 0 10px 20px rgba(0,0,0,.12);
      transition: transform .18s ease, box-shadow .18s ease;
    }}

    .clear-btn:hover {{
      transform: translateY(-1px);
      box-shadow: 0 14px 26px rgba(0,0,0,.16);
    }}

    .categories {{
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
      margin-top: 18px;
    }}

    .chip {{
      border: 1px solid rgba(255,255,255,.18);
      color: rgba(255,250,246,.92);
      border-radius: 999px;
      padding: 10px 14px;
      font-size: 13px;
      font-weight: 800;
      cursor: pointer;
      backdrop-filter: blur(8px);
      transition: transform .18s ease, background .18s ease, color .18s ease, border-color .18s ease;
      background: rgba(255,255,255,.10);
    }}

    .chip:hover {{
      transform: translateY(-1px);
      background: rgba(255,255,255,.18);
      color: #fff;
    }}

    .chip.active {{
      background: var(--chip-accent, #fffaf3);
      border-color: rgba(255,255,255,.48);
      color: #fff;
      box-shadow: 0 12px 24px rgba(0,0,0,.16);
    }}

    .chip[data-category="all"].active {{
      color: var(--accent);
      background: linear-gradient(180deg, #fffaf3 0%, #f0dec0 100%);
    }}

    main {{
      padding: 0 20px 52px;
    }}

    .resultbar {{
      margin: 18px 0 14px;
      color: var(--accent);
      font-size: 13px;
      font-weight: 800;
    }}

    .resultbar:empty {{
      display: none;
    }}

    .grid {{
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 18px;
    }}

    .card {{
      --cat-accent: var(--accent);
      --cat-soft: #f6e8ec;
      --cat-pale: #fbf4f6;
      position: relative;
      overflow: hidden;
      background: linear-gradient(180deg, rgba(255,255,255,.98) 0%, var(--cat-pale) 100%);
      border: 1px solid var(--cat-soft);
      border-radius: 24px;
      padding: 20px;
      box-shadow: var(--shadow);
      display: flex;
      flex-direction: column;
      gap: 14px;
      min-height: 260px;
      transition: transform .22s ease, box-shadow .22s ease, border-color .22s ease;
    }}

    .card::before {{
      content: "";
      position: absolute;
      left: 0;
      right: 0;
      top: 0;
      height: 5px;
      background: linear-gradient(90deg, var(--cat-accent), var(--gold));
    }}

    .card:hover {{
      transform: translateY(-4px);
      border-color: var(--cat-accent);
      box-shadow: 0 24px 42px rgba(34, 24, 16, .12);
    }}

    .card-top {{
      display: flex;
      justify-content: space-between;
      gap: 12px;
      align-items: flex-start;
    }}

    .name {{
      margin: 0;
      font-size: 24px;
      line-height: 1.15;
      letter-spacing: -.03em;
      word-break: break-word;
      color: #111;
    }}

    .category {{
      flex-shrink: 0;
      color: var(--cat-accent);
      background: var(--cat-soft);
      border: 1px solid var(--cat-soft);
      padding: 6px 10px;
      border-radius: 999px;
      font-size: 12px;
      font-weight: 800;
      letter-spacing: .02em;
    }}

    .language-pair {{
      display: grid;
      gap: 10px;
    }}

    .lang-block {{
      position: relative;
      padding: 12px 13px;
      border: 1px solid var(--cat-soft);
      border-radius: 16px;
      background: rgba(255,255,255,.66);
    }}

    .jp-block {{
      background: linear-gradient(180deg, var(--cat-soft), rgba(255,255,255,.74));
    }}

    .en-block {{
      background: linear-gradient(180deg, rgba(198,154,75,.10), rgba(255,255,255,.74));
    }}

    .label {{
      display: inline-flex;
      align-items: center;
      gap: 7px;
      color: var(--cat-accent);
      font-size: 11px;
      font-weight: 900;
      text-transform: uppercase;
      letter-spacing: .14em;
      margin-bottom: 6px;
    }}

    .label::before {{
      content: "";
      width: 7px;
      height: 7px;
      border-radius: 999px;
      background: var(--cat-accent);
      box-shadow: 0 0 0 4px var(--cat-soft);
    }}

    .primary-text {{
      margin: 0;
      font-size: 16px;
      line-height: 1.72;
      white-space: pre-wrap;
    }}

    .media {{
      display: grid;
      gap: 10px;
    }}

    .images {{
      display: grid;
      gap: 8px;
    }}

    .images img {{
      width: 100%;
      max-height: 220px;
      object-fit: contain;
      background: #fff;
      border: 1px solid var(--cat-soft);
      border-radius: 16px;
      padding: 6px;
    }}

    .links {{
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
      margin-top: auto;
      padding-top: 4px;
    }}

    .links a {{
      position: relative;
      text-decoration: none;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 44px;
      height: 44px;
      border: 1px solid var(--cat-soft);
      background: linear-gradient(180deg, var(--cat-soft), rgba(198,154,75,.12));
      color: var(--cat-accent);
      border-radius: 999px;
      transition: transform .15s ease, box-shadow .15s ease;
      box-shadow: 0 6px 14px rgba(15, 23, 42, .06);
    }}

    .links a:hover {{
      transform: translateY(-1px) scale(1.03);
      box-shadow: 0 12px 22px rgba(140,21,48,.16);
    }}

    .video-icon {{
      width: 20px;
      height: 20px;
      display: block;
      fill: currentColor;
    }}

    .link-index {{
      position: absolute;
      right: -3px;
      bottom: -3px;
      min-width: 17px;
      height: 17px;
      padding: 0 4px;
      border-radius: 999px;
      background: var(--cat-accent);
      color: #fff;
      font-size: 10px;
      font-weight: 800;
      line-height: 17px;
      text-align: center;
      box-shadow: 0 2px 6px rgba(0,0,0,.18);
    }}

    .sr-only {{
      position: absolute;
      width: 1px;
      height: 1px;
      padding: 0;
      margin: -1px;
      overflow: hidden;
      clip: rect(0, 0, 0, 0);
      white-space: nowrap;
      border: 0;
    }}

    .empty {{
      text-align: center;
      background: rgba(255,255,255,.84);
      border: 1px dashed rgba(125, 27, 43, .22);
      border-radius: 24px;
      padding: 52px 18px;
      color: var(--muted);
      display: none;
      box-shadow: 0 10px 24px rgba(34, 24, 16, .05);
    }}

    .empty.show {{
      display: block;
    }}

    mark {{
      background: rgba(198,154,75,.42);
      color: inherit;
      padding: 0 3px;
      border-radius: 4px;
    }}

    @media (max-width: 1100px) {{
      .grid {{ grid-template-columns: repeat(2, minmax(0, 1fr)); }}
    }}

    @media (max-width: 640px) {{
      body {{
        background:
          radial-gradient(circle at top right, rgba(140,21,48,.16), transparent 18rem),
          linear-gradient(180deg, #f8f3ee 0%, #fbf8f4 100%);
      }}

      header {{ padding: max(12px, env(safe-area-inset-top)) 10px 10px; }}
      main {{ padding: 0 10px max(28px, env(safe-area-inset-bottom)); }}
      .wrap {{ width: 100%; }}
      .hero {{ padding: 16px; border-radius: 24px; }}
      .eyebrow {{ margin-bottom: 10px; padding: 7px 11px; font-size: 9px; letter-spacing: .15em; }}
      h1 {{ font-size: clamp(34px, 12vw, 46px); }}
      .subtitle {{ margin-top: 10px; font-size: 13px; line-height: 1.65; }}
      .controls {{ grid-template-columns: 1fr; gap: 9px; margin-top: 16px; }}
      .searchbox input {{ min-height: 54px; border-radius: 18px; padding: 15px 50px 15px 16px; font-size: 16px; }}
      .clear-btn {{ width: 100%; min-height: 48px; border-radius: 16px; padding: 12px 16px; }}
      .categories {{
        width: 100%;
        max-width: 100%;
        min-width: 0;
        flex-wrap: nowrap;
        overflow-x: auto;
        overflow-y: hidden;
        gap: 8px;
        margin: 14px 0 -2px;
        padding: 0 0 8px;
        scroll-snap-type: x proximity;
        -webkit-overflow-scrolling: touch;
        overscroll-behavior-x: contain;
        touch-action: pan-x;
        contain: layout paint;
      }}
      .categories::-webkit-scrollbar {{ display: none; }}
      .chip {{ flex: 0 0 auto; min-height: 40px; padding: 9px 12px; font-size: 12px; white-space: nowrap; scroll-snap-align: start; }}
      .grid {{ grid-template-columns: 1fr; gap: 12px; }}
      .card {{ min-height: unset; padding: 16px; border-radius: 20px; gap: 11px; }}
      .card:hover {{ transform: none; }}
      .card-top {{ flex-direction: column; gap: 8px; }}
      .name {{ font-size: 23px; line-height: 1.12; }}
      .category {{ align-self: flex-start; white-space: normal; line-height: 1.25; }}
      .lang-block {{ padding: 11px 12px; border-radius: 15px; }}
      .label {{ font-size: 10px; margin-bottom: 5px; }}
      .primary-text {{ font-size: 15.5px; line-height: 1.62; }}
      .links a {{ width: 48px; height: 48px; }}
      .video-icon {{ width: 22px; height: 22px; }}
    }}
  </style>
</head>
<body>
  <header>
    <div class="wrap">
      <section class="hero">
        <div class="eyebrow">Japan Rugby • Bilingual Playbook</div>
        <h1>Terminology</h1>

        <div class="controls">
          <div class="searchbox">
            <input id="searchInput" type="search" autocomplete="off" placeholder="例: Red / タックル / kick / scrum" />
            <span class="search-icon">⌕</span>
          </div>
          <button class="clear-btn" id="clearBtn" type="button">Clear</button>
        </div>

        <div class="categories" id="categoryChips" aria-label="Category filter"></div>
      </section>
    </div>
  </header>

  <main>
    <div class="wrap">
      <div class="resultbar" id="activeInfo"></div>
      <section id="cards" class="grid"></section>
      <div id="empty" class="empty">該当するプレーがありません。</div>
    </div>
  </main>

<script>
const PLAYS = {plays_json};
const CATEGORY_COUNTS = {counts_json};
const CATEGORY_COLORS = {colors_json};

let state = {{
  query: "",
  category: "all"
}};

const $ = (id) => document.getElementById(id);

function normalize(value) {{
  return (value || "").toString().normalize("NFKC").toLowerCase();
}}

function escapeHTML(value) {{
  return (value || "").toString()
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}}

function highlight(text, query) {{
  const safe = escapeHTML(text || "");
  const q = normalize(query).trim();
  if (!q) return safe;
  const original = (text || "").toString();
  const normOriginal = normalize(original);
  const index = normOriginal.indexOf(q);
  if (index < 0) return safe;
  return escapeHTML(original.slice(0, index)) +
    "<mark>" + escapeHTML(original.slice(index, index + q.length)) + "</mark>" +
    escapeHTML(original.slice(index + q.length));
}}

function getCategories() {{
  return Object.keys(CATEGORY_COUNTS);
}}

function styleVars(category) {{
  const color = CATEGORY_COLORS[category] || CATEGORY_COLORS["Attack Philosophy"];
  return `--cat-accent: ${{color.accent}}; --cat-soft: ${{color.soft}}; --cat-pale: ${{color.pale}};`;
}}

function chipVars(category) {{
  const color = CATEGORY_COLORS[category];
  return color ? `--chip-accent: ${{color.accent}};` : "";
}}

function filteredPlays() {{
  const q = normalize(state.query).trim();
  return PLAYS.filter(play => {{
    const categoryOk = state.category === "all" || play.category === state.category;
    if (!categoryOk) return false;
    if (!q) return true;
    const haystack = normalize([
      play.category,
      play.name,
      play.english,
      play.japanese,
      ...(play.urls || []),
      ...(play.images || [])
    ].join(" "));
    return haystack.includes(q);
  }});
}}

function renderCategories() {{
  const chips = [`<button type="button" class="chip ${{state.category === "all" ? "active" : ""}}" data-category="all">All</button>`];
  for (const category of getCategories()) {{
    chips.push(`<button type="button" class="chip ${{state.category === category ? "active" : ""}}" data-category="${{escapeHTML(category)}}" style="${{chipVars(category)}}">${{escapeHTML(category)}}</button>`);
  }}
  $("categoryChips").innerHTML = chips.join("");

  document.querySelectorAll(".chip").forEach(chip => {{
    chip.addEventListener("click", () => {{
      state.category = chip.dataset.category;
      render();
    }});
  }});
}}

function renderImages(play) {{
  const images = play.images || [];
  if (!images.length) return "";
  return `<div class="images">` + images.map((src, index) =>
    `<img src="${{escapeHTML(src)}}" alt="${{escapeHTML(play.name)}} image ${{index + 1}}" loading="lazy">`
  ).join("") + `</div>`;
}}

function renderLinks(play) {{
  const urls = play.urls || [];
  if (!urls.length) return "";
  return urls.map((url, idx) => {{
    const label = `動画 ${{idx + 1}}`;
    const numberBadge = urls.length > 1 ? `<span class="link-index">${{idx + 1}}</span>` : "";
    return `<a href="${{escapeHTML(url)}}" target="_blank" rel="noopener noreferrer" aria-label="${{escapeHTML(label)}}" title="${{escapeHTML(label)}}">
      <svg class="video-icon" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M15 8.5V7A2 2 0 0 0 13 5H5A2 2 0 0 0 3 7v10a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2v-1.5l5 3V5.5l-5 3ZM10 15V9l4 3-4 3Z"/>
      </svg>
      <span class="sr-only">${{escapeHTML(label)}}</span>
      ${{numberBadge}}
    </a>`;
  }}).join("");
}}

function renderCards() {{
  const plays = filteredPlays();
  $("activeInfo").textContent = state.category === "all" ? "" : `カテゴリ: ${{state.category}}`;
  $("empty").classList.toggle("show", plays.length === 0);

  const q = state.query.trim();
  $("cards").innerHTML = plays.map(play => {{
    const jp = play.japanese || "—";
    const en = play.english || "—";
    const images = renderImages(play);
    const links = renderLinks(play);
    return `<article class="card" style="${{styleVars(play.category)}}">
      <div class="card-top">
        <h2 class="name">${{highlight(play.name, q)}}</h2>
        <span class="category">${{escapeHTML(play.category)}}</span>
      </div>

      <div class="language-pair">
        <div class="lang-block jp-block">
          <div class="label">JP</div>
          <p class="primary-text">${{highlight(jp, q)}}</p>
        </div>
        <div class="lang-block en-block">
          <div class="label">EN</div>
          <p class="primary-text">${{highlight(en, q)}}</p>
        </div>
      </div>

      ${{images ? `<div class="media">${{images}}</div>` : ""}}
      ${{links ? `<div class="links">${{links}}</div>` : ""}}
    </article>`;
  }}).join("");
}}

function render() {{
  renderCategories();
  renderCards();
}}

$("searchInput").addEventListener("input", event => {{
  state.query = event.target.value;
  state.category = "all";
  render();
}});

$("clearBtn").addEventListener("click", () => {{
  state.query = "";
  state.category = "all";
  $("searchInput").value = "";
  render();
  $("searchInput").focus();
}});

render();
</script>
</body>
</html>
"""

output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(html, encoding="utf-8")

print(f"Generated: {output_path}")
print(f"Items: {len(plays)}")
print(f"Categories: {len(category_counts)}")
PY
