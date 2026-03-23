#!/usr/bin/env bash
# Hämtar data från NHL:s öppna API och beräknar analytiska "findings"
# för datadrivna hockey-artiklar.
#
# Output: /data/.openclaw/nhl-data/latest.json
#
# Findings som beräknas:
#   regression_candidate_up   – team med bra GF% men låg pts% (underdog på väg upp)
#   regression_candidate_down – team med dålig GF% men hög pts% (bubbelkandidaten)
#   best_underlying           – laget med ligans bästa goal share
#   ot_dependent              – laget som lever och dör i övertid
#   home_road_split           – laget med dramatisk hemma/borta-skillnad
#
# Kräver: curl, python3. Ingen autentisering behövs (NHLs API är öppet).
# Körs av NHL-DATA-AUTO cron i OpenClaw eller manuellt.
#
# Användning: /data/.openclaw/scripts/nhl-data-fetch.sh

set -euo pipefail

OUTPUT_DIR="/data/.openclaw/nhl-data"
OUTPUT_FILE="$OUTPUT_DIR/latest.json"
TMP_DIR="/tmp/nhl-fetch-$$"
mkdir -p "$OUTPUT_DIR" "$TMP_DIR"
trap "rm -rf '$TMP_DIR'" EXIT

TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)

echo "[$TODAY] Fetching standings..." >&2
curl -sf --max-time 15 "https://api-web.nhle.com/v1/standings/now" \
  > "$TMP_DIR/standings.json" \
  || echo '{"standings":[]}' > "$TMP_DIR/standings.json"

echo "[$TODAY] Fetching scores for $YESTERDAY..." >&2
curl -sf --max-time 15 "https://api-web.nhle.com/v1/score/$YESTERDAY" \
  > "$TMP_DIR/scores.json" \
  || echo '{"games":[]}' > "$TMP_DIR/scores.json"

echo "[$TODAY] Fetching skater leaders..." >&2
curl -sf --max-time 15 \
  "https://api-web.nhle.com/v1/skater-stats-leaders/current?categories=goals,assists,points,plusMinus,shootingPctg&limit=5" \
  > "$TMP_DIR/skater-leaders.json" \
  || echo '{}' > "$TMP_DIR/skater-leaders.json"

echo "[$TODAY] Fetching goalie leaders..." >&2
curl -sf --max-time 15 \
  "https://api-web.nhle.com/v1/goalie-stats-leaders/current?categories=wins,savePct,gaa&limit=5" \
  > "$TMP_DIR/goalie-leaders.json" \
  || echo '{}' > "$TMP_DIR/goalie-leaders.json"

echo "[$TODAY] Computing analytics findings..." >&2

python3 - "$TMP_DIR" "$TODAY" "$YESTERDAY" <<'PYEOF'
import json, sys, os

tmp_dir = sys.argv[1]
today   = sys.argv[2]
yesterday = sys.argv[3]

def load(fname):
    try:
        with open(os.path.join(tmp_dir, fname)) as f:
            return json.load(f)
    except Exception:
        return {}

def str_val(v):
    """Safely extract string from NHL API values that may be dicts."""
    if isinstance(v, dict):
        return v.get('default', '')
    return str(v) if v is not None else ''

standings_raw  = load('standings.json')
scores_raw     = load('scores.json')
skater_raw     = load('skater-leaders.json')
goalie_raw     = load('goalie-leaders.json')

standings = standings_raw.get('standings', [])
games     = scores_raw.get('games', [])

# ── Team analytics ──────────────────────────────────────────────────────────
teams = []
for t in standings:
    gp = t.get('gamesPlayed', 0)
    if gp < 10:
        continue

    gf  = t.get('goalFor', 0)
    ga  = t.get('goalAgainst', 0)
    pts = t.get('points', 0)
    w   = t.get('wins', 0)
    l   = t.get('losses', 0)
    otl = t.get('otLosses', 0)
    row = t.get('regulationWins', w)   # regulation wins

    home_w  = t.get('homeWins', 0)
    road_w  = t.get('roadWins', 0)
    home_gp = t.get('homeGamesPlayed', gp // 2)
    road_gp = t.get('roadGamesPlayed', gp // 2)

    total_g  = gf + ga
    gf_pct   = round(gf / total_g * 100, 1) if total_g > 0 else 50.0
    pts_pct  = round(pts / (gp * 2) * 100, 1) if gp > 0 else 0.0
    gf_pg    = round(gf / gp, 2) if gp > 0 else 0.0
    ga_pg    = round(ga / gp, 2) if gp > 0 else 0.0
    gdiff    = gf - ga
    gdiff_pg = round(gdiff / gp, 2) if gp > 0 else 0.0

    # GF% is the best single-season predictor of pts%.
    # Diff > 0 means outperforming (lucky), < 0 means underperforming (unlucky).
    pts_diff = round(pts_pct - gf_pct, 1)

    ot_w      = w - row
    ot_dep    = round(ot_w / w * 100, 1) if w > 0 else 0.0

    teams.append({
        'abbrev'          : str_val(t.get('teamAbbrev', '')),
        'name'            : str_val(t.get('teamName', str_val(t.get('teamAbbrev', '')))),
        'gp'              : gp,
        'gf'              : gf,
        'ga'              : ga,
        'pts'             : pts,
        'wins'            : w,
        'losses'          : l,
        'otl'             : otl,
        'row'             : row,
        'ot_wins'         : ot_w,
        'ot_dependency_pct': ot_dep,
        'gf_pct'          : gf_pct,
        'pts_pct'         : pts_pct,
        'pts_pct_diff'    : pts_diff,
        'gf_per_game'     : gf_pg,
        'ga_per_game'     : ga_pg,
        'goal_diff'       : gdiff,
        'goal_diff_per_game': gdiff_pg,
        'home_wins'       : home_w,
        'road_wins'       : road_w,
        'home_gp'         : home_gp,
        'road_gp'         : road_gp,
        'conference'      : str_val(t.get('conferenceName', '')),
        'division'        : str_val(t.get('divisionName', '')),
        'league_sequence' : t.get('leagueSequence', 999),
    })

by_pts = sorted(teams, key=lambda x: -x['pts_pct'])

# ── Findings ─────────────────────────────────────────────────────────────────
findings = []

# 1. Most unlucky: high GF% but low pts%
unlucky = [t for t in teams if t['pts_pct_diff'] < -4]
if unlucky:
    t = sorted(unlucky, key=lambda x: x['pts_pct_diff'])[0]
    findings.append({
        'type'     : 'regression_candidate_up',
        'priority' : 1,
        'headline' : f"{t['name']} is due for a turnaround – the numbers say so",
        'data'     : t,
        'insight'  : (
            f"{t['name']} own a {t['gf_pct']}% goal share across {t['gp']} games "
            f"but sit at only a {t['pts_pct']}% points pace. "
            f"That {abs(t['pts_pct_diff'])}-point gap between performance and results "
            f"is one of the widest in the league. "
            f"Goal-share differentials this large historically close over a full season – "
            f"and the direction of travel almost always favours the team doing the underlying damage."
        ),
        'article_angle_thb'  : 'Deep GF% regression analysis – why pts% will converge to GF% over time',
        'article_angle_tha'  : 'Practical explainer for coaches – why shot/goal share matters more than the standings right now',
    })

# 2. Most lucky: low GF% but high pts%
lucky = [t for t in teams if t['pts_pct_diff'] > 4]
if lucky:
    t = sorted(lucky, key=lambda x: -x['pts_pct_diff'])[0]
    findings.append({
        'type'     : 'regression_candidate_down',
        'priority' : 2,
        'headline' : f"{t['name']}'s record is writing checks their underlying numbers can't cash",
        'data'     : t,
        'insight'  : (
            f"{t['name']} carry a {t['gf_pct']}% goal share but are running at a {t['pts_pct']}% points pace – "
            f"outperforming their underlying numbers by {t['pts_pct_diff']} points. "
            f"OT dependency is {t['ot_dependency_pct']}% of their wins. "
            f"When teams separate their results from their process this much, "
            f"regression is never a question of if – only when."
        ),
        'article_angle_thb'  : 'Analytics warning: identify the specific metrics driving the overperformance',
        'article_angle_tha'  : 'Red flags a coach should notice: what the standings hide about this team',
    })

# 3. Best underlying numbers (GF%)
if teams:
    t = sorted(teams, key=lambda x: -x['gf_pct'])[0]
    findings.append({
        'type'     : 'best_underlying',
        'priority' : 3,
        'headline' : f"{t['name']} leads the league in goal share – and that's the only number that matters long-term",
        'data'     : t,
        'insight'  : (
            f"With a {t['gf_pct']}% goal share – "
            f"scoring {t['gf_per_game']} and allowing {t['ga_per_game']} per game – "
            f"{t['name']} own the league's best underlying numbers. "
            f"Over a full season, GF% is the strongest single predictor of playoff success, "
            f"outperforming Corsi, PDO, and standings position in predictive accuracy."
        ),
        'article_angle_thb'  : 'Why GF% > Corsi as a in-season predictor – use this team as the case study',
        'article_angle_tha'  : 'Scouting intelligence: what makes this team the real contender, explained simply',
    })

# 4. OT dependency
ot_cands = [t for t in teams if t['wins'] >= 15 and t['ot_dependency_pct'] > 22]
if ot_cands:
    t = sorted(ot_cands, key=lambda x: -x['ot_dependency_pct'])[0]
    findings.append({
        'type'     : 'ot_dependent',
        'priority' : 4,
        'headline' : f"{t['name']} is surviving on overtime lottery tickets",
        'data'     : t,
        'insight'  : (
            f"{t['ot_dependency_pct']}% of {t['name']}'s {t['wins']} wins have come in OT or shootout. "
            f"Only {t['row']} are regulation wins from {t['gp']} games. "
            f"Teams this reliant on 3-on-3 hockey and shootouts are one bad goalie performance "
            f"away from a losing streak. The analytics community calls this 'points-percentage unsustainability' – "
            f"and history backs that up."
        ),
        'article_angle_thb'  : 'ROW vs W: quantify the risk embedded in OT-heavy records',
        'article_angle_tha'  : 'What overtime dependency means in practice – and why coaches should care',
    })

# 5. Biggest home/road split
splits = []
for t in teams:
    if t['home_gp'] >= 12 and t['road_gp'] >= 12 and t['home_gp'] > 0 and t['road_gp'] > 0:
        hw = round(t['home_wins'] / t['home_gp'] * 100, 1)
        rw = round(t['road_wins'] / t['road_gp'] * 100, 1)
        splits.append({**t, 'home_wpct': hw, 'road_wpct': rw, 'split': round(hw - rw, 1)})

if splits:
    t = sorted(splits, key=lambda x: -abs(x['split']))[0]
    if abs(t['split']) > 18:
        findings.append({
            'type'     : 'home_road_split',
            'priority' : 5,
            'headline' : f"{t['name']}: two completely different teams depending on the building",
            'data'     : {k: t[k] for k in
                         ['name','abbrev','home_wpct','road_wpct','home_wins','road_wins',
                          'home_gp','road_gp','split','gp','pts','gf_pct']},
            'insight'  : (
                f"{t['name']} win {t['home_wpct']}% at home but only {t['road_wpct']}% on the road – "
                f"a {abs(t['split']):.0f}-point win-rate gap. "
                f"Splits this large almost always indicate a specific structural issue: "
                f"line matching exposure, zone-start manipulation at home, or a goalie who plays better "
                f"in a familiar crease. Worth digging into."
            ),
            'article_angle_thb'  : 'What causes extreme home/road splits? Analyze zone starts, matchups, and goalie splits',
            'article_angle_tha'  : 'Coaching insight: home ice advantage is real – here\'s how to measure and exploit it',
        })

# ── Yesterday's games ─────────────────────────────────────────────────────────
games_summary = []
for g in games:
    state = g.get('gameState', '')
    if state not in ('FINAL', 'OFF'):
        continue
    home = g.get('homeTeam', {})
    away = g.get('awayTeam', {})
    hs   = home.get('score', 0)
    as_  = away.get('score', 0)
    pt   = g.get('periodDescriptor', {}).get('periodType', 'REG')
    games_summary.append({
        'home'        : home.get('abbrev', ''),
        'away'        : away.get('abbrev', ''),
        'home_score'  : hs,
        'away_score'  : as_,
        'winner'      : home.get('abbrev', '') if hs > as_ else away.get('abbrev', ''),
        'period_type' : pt,
    })

# ── Stat leaders ─────────────────────────────────────────────────────────────
leaders = {}
for cat in ['goals', 'assists', 'points', 'plusMinus', 'shootingPctg']:
    lst = skater_raw.get(cat, [])
    if lst:
        p = lst[0]
        name = f"{str_val(p.get('firstName',''))} {str_val(p.get('lastName',''))}".strip()
        leaders[cat] = {'player': name, 'team': p.get('teamAbbrevs', ''), 'value': p.get('value', 0)}

for cat in ['wins', 'savePct', 'gaa']:
    lst = goalie_raw.get(cat, [])
    if lst:
        p = lst[0]
        name = f"{str_val(p.get('firstName',''))} {str_val(p.get('lastName',''))}".strip()
        leaders[f'goalie_{cat}'] = {'player': name, 'team': p.get('teamAbbrevs', ''), 'value': p.get('value', 0)}

# ── Output ────────────────────────────────────────────────────────────────────
output = {
    'fetched_at'          : today,
    'data_date'           : yesterday,
    'findings'            : sorted(findings, key=lambda x: x['priority']),
    'top5_by_points_pct'  : [
        {
            'rank': i + 1,
            'team': t['name'], 'abbrev': t['abbrev'],
            'pts': t['pts'], 'gp': t['gp'],
            'gf_pct': t['gf_pct'], 'pts_pct': t['pts_pct'],
            'pts_pct_diff': t['pts_pct_diff'],
        }
        for i, t in enumerate(by_pts[:5])
    ],
    'yesterday_games'     : games_summary,
    'league_leaders'      : leaders,
    'total_teams_analyzed': len(teams),
    'all_teams'           : sorted(teams, key=lambda x: x['league_sequence']),
}

print(json.dumps(output, indent=2, ensure_ascii=False))
PYEOF

# Write to output file
python3 - "$TMP_DIR" "$TODAY" "$YESTERDAY" <<'PYEOF' > "$OUTPUT_FILE"
import json, sys, os

tmp_dir = sys.argv[1]
today   = sys.argv[2]
yesterday = sys.argv[3]

def load(fname):
    try:
        with open(os.path.join(tmp_dir, fname)) as f:
            return json.load(f)
    except Exception:
        return {}

def str_val(v):
    if isinstance(v, dict):
        return v.get('default', '')
    return str(v) if v is not None else ''

standings_raw  = load('standings.json')
scores_raw     = load('scores.json')
skater_raw     = load('skater-leaders.json')
goalie_raw     = load('goalie-leaders.json')

standings = standings_raw.get('standings', [])
games     = scores_raw.get('games', [])

teams = []
for t in standings:
    gp = t.get('gamesPlayed', 0)
    if gp < 10:
        continue
    gf  = t.get('goalFor', 0)
    ga  = t.get('goalAgainst', 0)
    pts = t.get('points', 0)
    w   = t.get('wins', 0)
    l   = t.get('losses', 0)
    otl = t.get('otLosses', 0)
    row = t.get('regulationWins', w)
    home_w  = t.get('homeWins', 0)
    road_w  = t.get('roadWins', 0)
    home_gp = t.get('homeGamesPlayed', gp // 2)
    road_gp = t.get('roadGamesPlayed', gp // 2)
    total_g  = gf + ga
    gf_pct   = round(gf / total_g * 100, 1) if total_g > 0 else 50.0
    pts_pct  = round(pts / (gp * 2) * 100, 1) if gp > 0 else 0.0
    gf_pg    = round(gf / gp, 2) if gp > 0 else 0.0
    ga_pg    = round(ga / gp, 2) if gp > 0 else 0.0
    gdiff    = gf - ga
    gdiff_pg = round(gdiff / gp, 2) if gp > 0 else 0.0
    pts_diff = round(pts_pct - gf_pct, 1)
    ot_w     = w - row
    ot_dep   = round(ot_w / w * 100, 1) if w > 0 else 0.0
    teams.append({
        'abbrev': str_val(t.get('teamAbbrev', '')),
        'name': str_val(t.get('teamName', str_val(t.get('teamAbbrev', '')))),
        'gp': gp, 'gf': gf, 'ga': ga, 'pts': pts,
        'wins': w, 'losses': l, 'otl': otl, 'row': row,
        'ot_wins': ot_w, 'ot_dependency_pct': ot_dep,
        'gf_pct': gf_pct, 'pts_pct': pts_pct, 'pts_pct_diff': pts_diff,
        'gf_per_game': gf_pg, 'ga_per_game': ga_pg,
        'goal_diff': gdiff, 'goal_diff_per_game': gdiff_pg,
        'home_wins': home_w, 'road_wins': road_w,
        'home_gp': home_gp, 'road_gp': road_gp,
        'conference': str_val(t.get('conferenceName', '')),
        'division': str_val(t.get('divisionName', '')),
        'league_sequence': t.get('leagueSequence', 999),
    })

by_pts = sorted(teams, key=lambda x: -x['pts_pct'])
findings = []

unlucky = [t for t in teams if t['pts_pct_diff'] < -4]
if unlucky:
    t = sorted(unlucky, key=lambda x: x['pts_pct_diff'])[0]
    findings.append({'type': 'regression_candidate_up', 'priority': 1,
        'headline': f"{t['name']} is due for a turnaround – the numbers say so",
        'data': t,
        'insight': (f"{t['name']} own a {t['gf_pct']}% goal share across {t['gp']} games "
            f"but sit at only a {t['pts_pct']}% points pace. "
            f"That {abs(t['pts_pct_diff'])}-point gap is one of the widest in the league. "
            f"Goal-share differentials this large historically close – and the direction "
            f"almost always favours the team doing the underlying damage."),
        'article_angle_thb': 'Deep GF% regression analysis – why pts% will converge to GF% over time',
        'article_angle_tha': 'Practical explainer – why shot/goal share matters more than the standings right now',
    })

lucky = [t for t in teams if t['pts_pct_diff'] > 4]
if lucky:
    t = sorted(lucky, key=lambda x: -x['pts_pct_diff'])[0]
    findings.append({'type': 'regression_candidate_down', 'priority': 2,
        'headline': f"{t['name']}'s record is writing checks their underlying numbers can't cash",
        'data': t,
        'insight': (f"{t['name']} carry a {t['gf_pct']}% goal share but run at a {t['pts_pct']}% points pace – "
            f"outperforming by {t['pts_pct_diff']} points. "
            f"OT dependency: {t['ot_dependency_pct']}% of wins. "
            f"When teams separate results from process this much, regression is never if – only when."),
        'article_angle_thb': 'Analytics warning: identify the specific metrics driving the overperformance',
        'article_angle_tha': 'Red flags a coach should notice: what the standings hide about this team',
    })

if teams:
    t = sorted(teams, key=lambda x: -x['gf_pct'])[0]
    findings.append({'type': 'best_underlying', 'priority': 3,
        'headline': f"{t['name']} leads the league in goal share – and that's the only number that matters long-term",
        'data': t,
        'insight': (f"With a {t['gf_pct']}% goal share – "
            f"scoring {t['gf_per_game']} and allowing {t['ga_per_game']} per game – "
            f"{t['name']} own the league's best underlying numbers. "
            f"Over a full season, GF% is the strongest single predictor of playoff success."),
        'article_angle_thb': 'Why GF% > Corsi as an in-season predictor – use this team as the case study',
        'article_angle_tha': 'Scouting intelligence: what makes this team the real contender, explained simply',
    })

ot_cands = [t for t in teams if t['wins'] >= 15 and t['ot_dependency_pct'] > 22]
if ot_cands:
    t = sorted(ot_cands, key=lambda x: -x['ot_dependency_pct'])[0]
    findings.append({'type': 'ot_dependent', 'priority': 4,
        'headline': f"{t['name']} is surviving on overtime lottery tickets",
        'data': t,
        'insight': (f"{t['ot_dependency_pct']}% of {t['name']}'s {t['wins']} wins have come in OT or shootout. "
            f"Only {t['row']} regulation wins from {t['gp']} games. "
            f"Teams this reliant on 3-on-3 and shootouts are one bad goalie performance "
            f"away from a losing streak."),
        'article_angle_thb': 'ROW vs W: quantify the risk embedded in OT-heavy records',
        'article_angle_tha': 'What OT dependency means in practice – and why coaches should care',
    })

splits = []
for t in teams:
    if t['home_gp'] >= 12 and t['road_gp'] >= 12:
        hw = round(t['home_wins'] / t['home_gp'] * 100, 1)
        rw = round(t['road_wins'] / t['road_gp'] * 100, 1)
        splits.append({**t, 'home_wpct': hw, 'road_wpct': rw, 'split': round(hw - rw, 1)})
if splits:
    t = sorted(splits, key=lambda x: -abs(x['split']))[0]
    if abs(t['split']) > 18:
        findings.append({'type': 'home_road_split', 'priority': 5,
            'headline': f"{t['name']}: two completely different teams depending on the building",
            'data': {k: t[k] for k in ['name','abbrev','home_wpct','road_wpct','home_wins',
                                        'road_wins','home_gp','road_gp','split','gp','pts','gf_pct']},
            'insight': (f"{t['name']} win {t['home_wpct']}% at home but only {t['road_wpct']}% on the road – "
                f"a {abs(t['split']):.0f}-point win-rate gap that's among the largest in the league."),
            'article_angle_thb': 'What causes extreme home/road splits? Zone starts, matchups, goalie splits',
            'article_angle_tha': "Coaching insight: home ice advantage is real – here's how to measure and exploit it",
        })

games_summary = []
for g in games:
    if g.get('gameState', '') not in ('FINAL', 'OFF'):
        continue
    home = g.get('homeTeam', {})
    away = g.get('awayTeam', {})
    hs = home.get('score', 0)
    as_ = away.get('score', 0)
    games_summary.append({
        'home': home.get('abbrev', ''), 'away': away.get('abbrev', ''),
        'home_score': hs, 'away_score': as_,
        'winner': home.get('abbrev', '') if hs > as_ else away.get('abbrev', ''),
        'period_type': g.get('periodDescriptor', {}).get('periodType', 'REG'),
    })

leaders = {}
for cat in ['goals', 'assists', 'points', 'plusMinus', 'shootingPctg']:
    lst = skater_raw.get(cat, [])
    if lst:
        p = lst[0]
        name = f"{str_val(p.get('firstName',''))} {str_val(p.get('lastName',''))}".strip()
        leaders[cat] = {'player': name, 'team': p.get('teamAbbrevs', ''), 'value': p.get('value', 0)}
for cat in ['wins', 'savePct', 'gaa']:
    lst = goalie_raw.get(cat, [])
    if lst:
        p = lst[0]
        name = f"{str_val(p.get('firstName',''))} {str_val(p.get('lastName',''))}".strip()
        leaders[f'goalie_{cat}'] = {'player': name, 'team': p.get('teamAbbrevs', ''), 'value': p.get('value', 0)}

output = {
    'fetched_at': today, 'data_date': yesterday,
    'findings': sorted(findings, key=lambda x: x['priority']),
    'top5_by_points_pct': [
        {'rank': i+1, 'team': t['name'], 'abbrev': t['abbrev'],
         'pts': t['pts'], 'gp': t['gp'],
         'gf_pct': t['gf_pct'], 'pts_pct': t['pts_pct'], 'pts_pct_diff': t['pts_pct_diff']}
        for i, t in enumerate(by_pts[:5])
    ],
    'yesterday_games': games_summary,
    'league_leaders': leaders,
    'total_teams_analyzed': len(teams),
    'all_teams': sorted(teams, key=lambda x: x['league_sequence']),
}

print(json.dumps(output, indent=2, ensure_ascii=False))
PYEOF

echo "[$TODAY] Done. Written to $OUTPUT_FILE" >&2
echo "$OUTPUT_FILE"
