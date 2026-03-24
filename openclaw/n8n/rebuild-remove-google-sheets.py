#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Rebuild tha-seogenerator and eik-seo-generator to remove Google Sheets dependency.
  - Replace 'Read Keywords from Google Sheets' with a Code node (hardcoded keyword list)
  - Update 'Pick Random Keyword' to work without status-filtering
  - eik: Remove 'Save Draft to Google Sheets' (mid-chain node) and rewire connections
  - Remove all googleSheetsOAuth2Api credentials from nodes
"""

import json, subprocess, os

PG      = "postgresql-j88kgkks44cc8wcc4kc8wkkk"
N8N     = "n8n-j88kgkks44cc8wcc4kc8wkkk"
PG_USER = "PefWbNMopVEj6wZj"
DB      = "n8n"

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
    subprocess.run(
        ["docker", "cp", fname, f"{N8N}:/home/node/wf_{label}.json"],
        check=True, capture_output=True
    )
    r = subprocess.run(
        ["docker", "exec", N8N, "n8n", "import:workflow",
         f"--input=/home/node/wf_{label}.json"],
        capture_output=True, text=True
    )
    print(f"  rc={r.returncode} | {r.stdout[-300:].strip()}")
    return r.returncode == 0

# ─── Keyword lists ────────────────────────────────────────────────────────────

THA_KEYWORDS_CODE = """
// THA SEO Keywords – redigera listan för att lägga till/ta bort keywords
const keywords = [
  { keyword: "corsi-fenwick-hockey-analytics", category: "metrics", priority: "high" },
  { keyword: "expected-goals-xg-nhl", category: "metrics", priority: "high" },
  { keyword: "zone-entries-exits-hockey", category: "metrics", priority: "high" },
  { keyword: "shot-quality-metrics-nhl", category: "metrics", priority: "high" },
  { keyword: "puck-possession-analytics-nhl", category: "metrics", priority: "high" },
  { keyword: "powerplay-analytics-nhl", category: "tactics", priority: "medium" },
  { keyword: "penalty-kill-analytics-hockey", category: "tactics", priority: "medium" },
  { keyword: "goalie-save-percentage-advanced-stats", category: "goalie", priority: "high" },
  { keyword: "goalie-consistency-metrics", category: "goalie", priority: "medium" },
  { keyword: "defensive-metrics-hockey-defenseman", category: "defense", priority: "medium" },
  { keyword: "offensive-zone-percentage-nhl", category: "metrics", priority: "medium" },
  { keyword: "points-per-60-minutes-hockey", category: "metrics", priority: "medium" },
  { keyword: "win-probability-model-nhl", category: "models", priority: "medium" },
  { keyword: "stanley-cup-prediction-analytics", category: "models", priority: "low" },
  { keyword: "nhl-draft-analytics-player-projection", category: "player-eval", priority: "medium" },
  { keyword: "shooting-percentage-regression-nhl", category: "metrics", priority: "medium" },
  { keyword: "faceoff-analytics-nhl", category: "metrics", priority: "low" },
  { keyword: "line-combination-analytics-nhl", category: "tactics", priority: "medium" },
  { keyword: "nhl-salary-cap-analytics", category: "business", priority: "low" },
  { keyword: "shl-analytics-sweden", category: "leagues", priority: "medium" },
  { keyword: "hockey-heat-maps-shot-charts", category: "visualization", priority: "medium" },
  { keyword: "nhl-trade-deadline-analytics", category: "business", priority: "low" },
  { keyword: "high-danger-scoring-chances-nhl", category: "metrics", priority: "high" },
  { keyword: "relative-corsi-nhl", category: "metrics", priority: "medium" },
  { keyword: "zone-starts-hockey-analytics", category: "metrics", priority: "medium" },
  { keyword: "nhl-forward-evaluation-analytics", category: "player-eval", priority: "medium" },
  { keyword: "hockey-analytics-beginners-guide", category: "education", priority: "high" },
  { keyword: "nhl-data-science-applications", category: "education", priority: "medium" },
  { keyword: "how-to-use-moneypuck-data", category: "education", priority: "medium" },
  { keyword: "nhl-api-hockey-data-tutorial", category: "education", priority: "medium" }
];

return keywords.map(k => ({ json: k }));
""".strip()

EIK_KEYWORDS_CODE = """
// EIK SEO Keywords – redigera listan för att lägga till/ta bort keywords
const keywords = [
  { keyword: "databricks-getting-started-guide", category: "databricks", priority: "high" },
  { keyword: "databricks-delta-lake-tutorial", category: "databricks", priority: "high" },
  { keyword: "mlflow-experiment-tracking-python", category: "mlops", priority: "high" },
  { keyword: "databricks-unity-catalog-guide", category: "databricks", priority: "medium" },
  { keyword: "apache-spark-dataframe-optimization", category: "spark", priority: "high" },
  { keyword: "python-data-analysis-workflow", category: "python", priority: "high" },
  { keyword: "machine-learning-sports-analytics", category: "ml", priority: "high" },
  { keyword: "feature-engineering-guide-python", category: "ml", priority: "medium" },
  { keyword: "data-driven-decision-making-business", category: "analytics", priority: "medium" },
  { keyword: "sql-analytics-best-practices", category: "sql", priority: "medium" },
  { keyword: "data-visualization-python-matplotlib", category: "visualization", priority: "medium" },
  { keyword: "ai-agents-practical-guide", category: "ai", priority: "high" },
  { keyword: "llm-applications-data-engineering", category: "ai", priority: "high" },
  { keyword: "chat-with-data-ai-product", category: "ai", priority: "high" },
  { keyword: "proactive-ai-agents-explained", category: "ai", priority: "medium" },
  { keyword: "databricks-automl-tutorial", category: "databricks", priority: "medium" },
  { keyword: "medallion-architecture-data-lakehouse", category: "architecture", priority: "medium" },
  { keyword: "real-time-analytics-streaming", category: "architecture", priority: "medium" },
  { keyword: "data-engineering-career-path", category: "career", priority: "low" },
  { keyword: "python-polars-vs-pandas", category: "python", priority: "medium" }
];

return keywords.map(k => ({ json: k }));
""".strip()

# Updated Pick Random Keyword code (no status filter needed)
PICK_RANDOM_CODE = """
const allKeywords = $input.all();

if (allKeywords.length === 0) {
  throw new Error('Keyword list is empty');
}

const selected = allKeywords[Math.floor(Math.random() * allKeywords.length)];

return {
  keyword: selected.json.keyword,
  category: selected.json.category || '',
  priority: selected.json.priority || 'medium'
};
""".strip()


# ─── 1. tha-seogenerator ─────────────────────────────────────────────────────
print("\n[1/2] Rebuilding tha-seogenerator (9R1IVjLC2c2LN51n)")
wf = get_wf("9R1IVjLC2c2LN51n")
nodes = wf["nodes"]

# Find existing nodes
gsheets_node = next(n for n in nodes if n["name"] == "Read Keywords from Google Sheets")
pick_node    = next(n for n in nodes if n["name"] == "Pick Random Keyword")

# Replace Google Sheets node with Keyword List Code node (keep same id so connections stay valid)
gsheets_node["name"]        = "Keyword List"
gsheets_node["type"]        = "n8n-nodes-base.code"
gsheets_node["typeVersion"] = 2
gsheets_node["parameters"]  = {
    "jsCode": THA_KEYWORDS_CODE,
    "mode": "runOnceForAllItems"
}
gsheets_node.pop("credentials", None)

# Update Pick Random Keyword to not filter by status
pick_node["parameters"] = {"jsCode": PICK_RANDOM_CODE}

# Update connections: rename "Read Keywords from Google Sheets" → "Keyword List"
conn = wf["connections"]
if "Read Keywords from Google Sheets" in conn:
    conn["Keyword List"] = conn.pop("Read Keywords from Google Sheets")
# Also fix any edges that point to the old name
for src, data in conn.items():
    for port in data.get("main", []):
        for edge in port:
            if edge.get("node") == "Read Keywords from Google Sheets":
                edge["node"] = "Keyword List"
# Fix the "Notify Slack" connection leftover from before
for src, data in conn.items():
    for port in data.get("main", []):
        for edge in port:
            if edge.get("node") == "Notify Slack":
                edge["node"] = "Notify Telegram"

wf["active"] = True
ok = import_wf(wf, "tha_seo_rebuild")
if ok:
    subprocess.run(
        ["docker", "exec", N8N, "n8n", "update:workflow",
         "--id=9R1IVjLC2c2LN51n", "--active=true"],
        capture_output=True
    )
    print("  ✅ OK – Google Sheets removed, 30 THA keywords inbyggda")
else:
    print("  ❌ FAILED")


# ─── 2. eik-seo-generator ────────────────────────────────────────────────────
print("\n[2/2] Rebuilding eik-seo-generator (YwlTkR687mZ1HMEY)")
wf = get_wf("YwlTkR687mZ1HMEY")
nodes = wf["nodes"]
conn  = wf["connections"]

# Replace Google Sheets read node
gsheets_node = next(n for n in nodes if n["name"] == "Read Keywords from Google Sheets")
gsheets_node["name"]        = "Keyword List"
gsheets_node["type"]        = "n8n-nodes-base.code"
gsheets_node["typeVersion"] = 2
gsheets_node["parameters"]  = {
    "jsCode": EIK_KEYWORDS_CODE,
    "mode": "runOnceForAllItems"
}
gsheets_node.pop("credentials", None)

# Update Pick Random Keyword
pick_node = next(n for n in nodes if n["name"] == "Pick Random Keyword")
pick_node["parameters"] = {"jsCode": PICK_RANDOM_CODE}

# Remove Save Draft to Google Sheets node
save_node = next((n for n in nodes if n["name"] == "Save Draft to Google Sheets"), None)
if save_node:
    nodes.remove(save_node)
    print("  Removed 'Save Draft to Google Sheets' node")

# Fix connections:
#   Before: Build Final Markdown → [Save Draft to Google Sheets, Generate Emil Personal Insights]
#   After:  Build Final Markdown → [Generate Emil Personal Insights]
if "Build Final Markdown" in conn:
    ports = conn["Build Final Markdown"]["main"]
    # Flatten all edges from all ports, remove the Save Draft edge
    new_edges = []
    for port in ports:
        for edge in port:
            if edge.get("node") != "Save Draft to Google Sheets":
                new_edges.append(edge)
    # Rebuild as single port with remaining edges
    conn["Build Final Markdown"]["main"] = [new_edges]

# Remove the Save Draft node's own connection entry
conn.pop("Save Draft to Google Sheets", None)

# Rename Google Sheets read connection
if "Read Keywords from Google Sheets" in conn:
    conn["Keyword List"] = conn.pop("Read Keywords from Google Sheets")
for src, data in conn.items():
    for port in data.get("main", []):
        for edge in port:
            if edge.get("node") == "Read Keywords from Google Sheets":
                edge["node"] = "Keyword List"

wf["active"] = True
ok = import_wf(wf, "eik_seo_rebuild")
if ok:
    subprocess.run(
        ["docker", "exec", N8N, "n8n", "update:workflow",
         "--id=YwlTkR687mZ1HMEY", "--active=true"],
        capture_output=True
    )
    print("  ✅ OK – Google Sheets removed, 20 EIK keywords inbyggda")
else:
    print("  ❌ FAILED")

print("\n— Restarting n8n —")
r = subprocess.run(["docker", "restart", N8N], capture_output=True, text=True)
print(f"  restart rc={r.returncode}")
