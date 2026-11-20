#!/usr/bin/env bash
# Read-only upgrade impact scan for a Pimcore project. For every documented
# breaking-change item in platform-impact-rules.json it lists each project file
# and line that matches. It never changes anything.
# Usage: scan-platform-impact.sh [project-root] [--to 12|2024|2025|2026] [--format table|json] [--max <n>]
#   --to      include rules for upgrade steps up to this one (default 2026).
#             2024 = deprecations in 11.5 and 2024.x, 2025 = Pimcore 12 and 2025.x (12 is an alias), 2026 = 2026.x
#   --format  table (default) or json
#   --max     matches kept per rule (default 200; the total count is still reported)

ROOT="$PWD"; TO="2026"; FORMAT="table"; MAX="200"
while [ $# -gt 0 ]; do
  case "$1" in
    --to) TO="${2:-}"; shift 2 ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --max) MAX="${2:-}"; shift 2 ;;
    -h|--help) sed -n 2,10p "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --*) echo "{\"error\":\"unknown option $1\"}"; exit 2 ;;
    *) ROOT="$1"; shift ;;
  esac
done
case "$FORMAT" in table|json) ;; *) echo '{"error":"--format must be table or json"}'; exit 2 ;; esac
case "$MAX" in ''|*[!0-9]*) echo '{"error":"--max must be a number"}'; exit 2 ;; esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" 2>/dev/null || { echo '{"error":"project root not found"}'; exit 1; }
ROOT="$PWD"

if command -v python3 >/dev/null 2>&1; then PY=python3
elif command -v python >/dev/null 2>&1 && python -c 'import sys; sys.exit(sys.version_info[0] < 3)' 2>/dev/null; then PY=python
else echo '{"error":"python3 is required for the scan"}'; exit 1; fi

RULES="$SCRIPT_DIR/platform-impact-rules.json"
[ -f "$RULES" ] || { echo '{"error":"platform-impact-rules.json missing next to the script"}'; exit 1; }

exec "$PY" - "$ROOT" "$RULES" "$TO" "$FORMAT" "$MAX" <<'PYEOF'
import fnmatch, json, os, re, sys
root, rules_path, to, fmt, maxn = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
with open(rules_path, encoding="utf-8") as fh:
    data = json.load(fh)
steps = data["steps"]
aliases = data.get("aliases", {})
target = aliases.get(to, to)
if target not in steps:
    print(json.dumps({"error": "--to must be one of " + ", ".join(steps + sorted(aliases))}))
    sys.exit(2)
limit = steps.index(target)
rules = [r for r in data["rules"] if steps.index(r["step"]) <= limit]

SKIP_DIRS = {"vendor", "var", "node_modules", ".git", ".idea", ".vscode", ".claude/worktrees", "public/bundles", "public/var", "public/build"}
KINDS = {
    "php": lambda n: n.endswith(".php"),
    "twig": lambda n: n.endswith((".twig", ".html.twig")),
    "yaml": lambda n: n.endswith((".yaml", ".yml")),
    "js": lambda n: n.endswith((".js", ".ts")) and not n.endswith(".min.js"),
    "sql": lambda n: n.endswith(".sql"),
    "env": lambda n: n == ".env" or n.startswith(".env."),
    "shell": lambda n: n.endswith((".sh", ".bash")) or n == "Makefile",
    "docker": lambda n: n.startswith("Dockerfile") or n.startswith("docker-compose") or n.startswith("compose."),
}
CI_DIRS = (".github", ".gitlab", ".circleci", ".docker", "docker", ".ddev", "deploy", "ci")

files = []
for dirpath, dirnames, filenames in os.walk(root):
    rel_dir = os.path.relpath(dirpath, root).replace(os.sep, "/")
    rel_dir = "" if rel_dir == "." else rel_dir
    dirnames[:] = [d for d in dirnames
                   if d not in SKIP_DIRS and (rel_dir + "/" + d).lstrip("/") not in SKIP_DIRS]
    for f in filenames:
        p = os.path.join(dirpath, f)
        try:
            if os.path.getsize(p) > 1_000_000 or os.path.islink(p):
                continue
        except OSError:
            continue
        files.append(((rel_dir + "/" + f).lstrip("/"), p, f))

def kinds_of(rel, name):
    out = [k for k, fn in KINDS.items() if fn(name)]
    top = rel.split("/")[0]
    if top in CI_DIRS or name in (".gitlab-ci.yml", "Jenkinsfile", "bitbucket-pipelines.yml"):
        out.append("ci")
    return out

cache = {}
def lines_of(path):
    if path not in cache:
        try:
            with open(path, encoding="utf-8", errors="ignore") as fh:
                cache[path] = fh.read().splitlines()
        except OSError:
            cache[path] = []
    return cache[path]

def composer():
    try:
        with open(os.path.join(root, "composer.json"), encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return None
cj = composer()
cj_lines = lines_of(os.path.join(root, "composer.json")) if cj is not None else []

def find_line(needle):
    for i, ln in enumerate(cj_lines, 1):
        if needle in ln:
            return i
    return 1

results = []
for r in rules:
    matches = []
    kind = r["kind"]
    if kind == "grep":
        pats = [re.compile(p) for p in r["patterns"]]
        skip = [re.compile(p) for p in r.get("excludeLineIf", [])]
        want = set(r["files"])
        for rel, p, name in files:
            if not (want & set(kinds_of(rel, name))):
                continue
            for i, ln in enumerate(lines_of(p), 1):
                if len(ln) > 2000:
                    continue
                if any(s.search(ln) for s in skip):
                    continue
                if any(x.search(ln) for x in pats):
                    matches.append({"file": rel, "line": i, "text": ln.strip()[:160]})
    elif kind == "composer" and cj is not None:
        pats = [re.compile(x) for x in r["patterns"]]
        for sect in ("require", "require-dev"):
            for pkg, cons in (cj.get(sect) or {}).items():
                if any(x.search(pkg) for x in pats):
                    matches.append({"file": "composer.json", "line": find_line('"' + pkg + '"'), "text": f"{pkg}: {cons}"})
    elif kind == "composer-constraint" and cj is not None:
        pats = [re.compile(x) for x in r["patterns"]]
        for path in r["paths"]:
            node, ok = cj, True
            for key in path[:-1]:
                node = node.get(key) if isinstance(node, dict) else None
                if node is None:
                    ok = False
                    break
            if not ok or not isinstance(node, dict):
                continue
            last = path[-1]
            for k, v in node.items():
                if fnmatch.fnmatch(k, last) and isinstance(v, str) and any(x.search(v) for x in pats):
                    matches.append({"file": "composer.json", "line": find_line('"' + k + '"'), "text": f"{'.'.join(path[:-1])}.{k}: {v}"})
    total = len(matches)
    results.append({
        "id": r["id"], "step": r["step"], "title": r["title"], "confidence": r["confidence"],
        "advice": r["advice"], "source": r["source"],
        "total": total, "files": len({m["file"] for m in matches}),
        "truncated": total > maxn, "matches": matches[:maxn],
    })

hit = [x for x in results if x["total"]]
summary = {"rulesChecked": len(results), "rulesWithMatches": len(hit),
           "totalMatches": sum(x["total"] for x in results),
           "filesAffected": len({m["file"] for x in results for m in x["matches"]})}
report = {"root": os.path.abspath(root), "to": to, "readOnly": True, "summary": summary,
          "notApplicable": [x["id"] for x in results if not x["total"]], "findings": hit,
          "limits": "Only items listed in platform-impact-rules.json are checked. 'heuristic' matches can be unrelated code. This is not a PHP deprecation report."}

if fmt == "json":
    print(json.dumps(report, indent=2))
    sys.exit(0)

print(f"Upgrade impact scan: {report['root']}  (steps up to {to}, read-only)")
print(f"{summary['rulesWithMatches']} of {summary['rulesChecked']} checks matched, {summary['totalMatches']} matches in {summary['filesAffected']} files.\n")
for x in hit:
    print(f"[{x['step']}] {x['id']}  ({x['confidence']})  {x['total']} match(es) in {x['files']} file(s)")
    print(f"  {x['title']}")
    for m in x["matches"]:
        print(f"    {m['file']}:{m['line']}  {m['text']}")
    if x["truncated"]:
        print(f"    ... {x['total'] - len(x['matches'])} more (use --max or --format json)")
    print(f"  Do: {x['advice']}")
    print(f"  Source: {x['source']}\n")
if report["notApplicable"]:
    print("No match: " + ", ".join(report["notApplicable"]))
print("\n" + report["limits"])
PYEOF
