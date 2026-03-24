#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Migrate 4 n8n workflows from Slack to Telegram notifications."""

import json, subprocess, os

PG      = "postgresql-j88kgkks44cc8wcc4kc8wkkk"
N8N     = "n8n-j88kgkks44cc8wcc4kc8wkkk"
PG_USER = "PefWbNMopVEj6wZj"
DB      = "n8n"
TG_CHAT = "-1003767033253"
TG_TOKEN = "8683132686:AAF5yJ206OcLKsSBx0n4Nm4uBAxcQlRbwyc"
TG_API  = f"https://api.telegram.org/bot{TG_TOKEN}/sendMessage"

def psql(sql):
    r = subprocess.run(
        ["docker", "exec", PG, "psql", "-U", PG_USER, "-d", DB, "-t", "-c", sql],
        capture_output=True, text=True, check=True
    )
    return r.stdout.strip()

def get_wf(wf_id):
    sql = (
        "SELECT json_build_object('id', id, 'name', name, 'nodes', nodes, "
        "'connections', connections, 'active', active, 'settings', settings, "
        f"'staticData', \"staticData\") FROM workflow_entity WHERE id='{wf_id}';"
    )
    return json.loads(psql(sql).strip())

def import_wf(wf_data, label):
    fname = f"/tmp/wf_{label}.json"
    with open(fname, "w", encoding="utf-8") as f:
        json.dump(wf_data, f, ensure_ascii=False)
    r1 = subprocess.run(
        ["docker", "cp", fname, f"{N8N}:/home/node/wf_{label}.json"],
        capture_output=True, text=True
    )
    if r1.returncode != 0:
        print(f"  cp FAILED: {r1.stderr[:300]}")
        return False
    r2 = subprocess.run(
        ["docker", "exec", N8N, "n8n", "import:workflow",
         f"--input=/home/node/wf_{label}.json"],
        capture_output=True, text=True
    )
    # Print last 400 chars of stdout to see result after deprecation warning
    print(f"  rc={r2.returncode} | {r2.stdout[-400:].strip()}")
    return r2.returncode == 0

def tg_jsonbody(text):
    """Build n8n jsonBody starting with = for expression evaluation."""
    # Escape backslashes first, then quotes, then encode newlines as JSON \n
    t = text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return f'={{"chat_id": "{TG_CHAT}", "text": "{t}", "parse_mode": "HTML"}}'

def tg_params(text):
    return {
        "method": "POST",
        "url": TG_API,
        "sendBody": True,
        "specifyBody": "json",
        "jsonBody": tg_jsonbody(text),
        "options": {}
    }

def patch_node(nodes, node_id, new_name, new_params, new_type=None):
    for n in nodes:
        if n["id"] == node_id:
            old_name = n["name"]
            n["name"] = new_name
            n["parameters"] = new_params
            if new_type:
                n["type"] = new_type
                n["typeVersion"] = 4.2
                n.pop("credentials", None)
                n.pop("webhookId", None)
            return old_name
    raise KeyError(f"Node {node_id} not found")

def rename_conn(connections, old_name, new_name):
    if old_name in connections:
        connections[new_name] = connections.pop(old_name)
    for src, data in connections.items():
        for port in data.get("main", []):
            for edge in port:
                if edge.get("node") == old_name:
                    edge["node"] = new_name


# ─── 1. tha-seogenerator ──────────────────────────────────────────────────────
print("\n[1/4] tha-seogenerator")
wf = get_wf("9R1IVjLC2c2LN51n")
old = patch_node(wf["nodes"], "c40686f0-5b53-4566-a52e-06ae0ba5eed5", "Notify Telegram",
    tg_params(
        "📝 <b>Ny SEO-artikel – The Hockey Analytics</b>\n\n"
        "<b>Keyword:</b> {{ $('Pick Random Keyword').item.json.keyword }}\n"
        "<b>Titel:</b> {{ $('Format & Extract Metadata').item.json.title }}\n"
        "<b>Slug:</b> /posts/{{ $('Format & Extract Metadata').item.json.slug }}\n"
        "<b>Kategori:</b> {{ $('Pick Random Keyword').item.json.category || '–' }}\n\n"
        "<b>Meta:</b>\n{{ $('Format & Extract Metadata').item.json.metaDescription }}\n\n"
        "<b>Preview:</b>\n{{ $('Format & Extract Metadata').item.json.content.substring(0, 300) }}...\n\n"
        "📖 Utkast: {{ $json.previewUrl }}\n"
        "✅ Godkänn: {{ $json.approveUrl }}\n"
        "❌ Avvisa: {{ $json.rejectUrl }}"
    )
)
rename_conn(wf["connections"], old, "Notify Telegram")
wf["active"] = True
ok = import_wf(wf, "tha_seo")
print("  ✅ OK" if ok else "  ❌ FAILED")


# ─── 2. eik-seo-generator ────────────────────────────────────────────────────
print("\n[2/4] eik-seo-generator")
wf = get_wf("YwlTkR687mZ1HMEY")
old = patch_node(wf["nodes"], "dc64340d-5419-4e9f-9185-2d6e1eb3fd15", "Notify Telegram",
    tg_params(
        "📋 <b>Artikelgranskning – emilingemarkarlsson.com</b>\n\n"
        "<b>Titel:</b> {{ $('Build Enhanced Markdown (E-A-T)').item.json.title }}\n"
        "<b>Keyword:</b> {{ $('Build Enhanced Markdown (E-A-T)').item.json.keyword }}\n"
        "<b>Slug:</b> /blog/{{ $('Build Enhanced Markdown (E-A-T)').item.json.slug }}\n\n"
        "🎯 E-A-T Score: <b>{{ $('Build Enhanced Markdown (E-A-T)').item.json.quality_score }}/10</b>\n"
        "✅ Checkar: {{ $('Build Enhanced Markdown (E-A-T)').item.json.passed_checks }}\n\n"
        "Publicera med:\n"
        "<code>publicera {{ $('Build Enhanced Markdown (E-A-T)').item.json.slug }}</code>"
    )
)
rename_conn(wf["connections"], old, "Notify Telegram")
wf["active"] = True
ok = import_wf(wf, "eik_seo")
print("  ✅ OK" if ok else "  ❌ FAILED")


# ─── 3. tha-dailyumamireport ─────────────────────────────────────────────────
print("\n[3/4] tha-dailyumamireport  → activate")
wf = get_wf("seIw4UJpNNPoXvli")
old = patch_node(wf["nodes"], "42dd3aa2-1339-4549-8091-8177fdf0a2c8", "Send Telegram Report",
    tg_params(
        "📊 <b>Daglig trafik – The Hockey Analytics</b>\n"
        "📅 {{ $('Set Date Range (Yesterday)').item.json.report_date }}\n\n"
        "👥 Besökare: <b>{{ $json.unique_visitors }}</b>\n"
        "📄 Sidvisningar: <b>{{ $json.total_visits }}</b>\n"
        "⏱ Snitt-tid: <b>{{ Math.floor($json.avg_visit_time / 60) }}m "
        "{{ $json.avg_visit_time % 60 }}s</b>\n"
        "🚪 Bounce: <b>{{ $json.bounce_rate }}%</b>\n\n"
        "<b>Toppsidor:</b>\n{{ $json.top_pages }}\n\n"
        "<b>Events:</b>\n{{ $json.events_summary }}\n\n"
        "🔗 umami.theunnamedroads.com"
    )
)
rename_conn(wf["connections"], old, "Send Telegram Report")
wf["active"] = True   # was inactive – activate
ok = import_wf(wf, "umami")
print("  ✅ OK" if ok else "  ❌ FAILED")


# ─── 4. Tur-Eik Website Analytics ────────────────────────────────────────────
print("\n[4/4] Tur-Eik Website Analytics  → keep inactive")
wf = get_wf("iIz2sKZIUEg00ECJ")
old = patch_node(wf["nodes"], "0de1ac0b-6a00-43ff-b6bf-329b0d90ea59", "Send Telegram Notification",
    tg_params(
        "🌐 <b>Ny besökare – {{ $json.domain }}</b>\n\n"
        "📄 {{ $json.page }}  ({{ $json.pageType }})\n"
        "📍 Källa: {{ $json.referrerType }}\n"
        "⏰ {{ $json.readableTime }}"
    ),
    new_type="n8n-nodes-base.httpRequest"   # was n8n-nodes-base.slack
)
rename_conn(wf["connections"], old, "Send Telegram Notification")
wf["active"] = False   # keep inactive
ok = import_wf(wf, "gtm")
print("  ✅ OK" if ok else "  ❌ FAILED")


print("\n— Restart n8n to apply all changes —")
r = subprocess.run(
    ["docker", "restart", N8N],
    capture_output=True, text=True
)
print(f"Restart: {r.returncode} {r.stdout.strip() or r.stderr.strip()[:100]}")
