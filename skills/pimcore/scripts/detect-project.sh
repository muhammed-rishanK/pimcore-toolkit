#!/usr/bin/env bash
# Read-only project detection for /pimcore. Prints a short JSON summary of the
# Pimcore project: versions, installed Pimcore bundles, runtime, tests, tooling
# and project instruction files. Never changes anything.
# Usage: detect-project.sh [project-root]   (default: current directory)

ROOT="${1:-$PWD}"
cd "$ROOT" 2>/dev/null || { echo '{"error":"project root not found"}'; exit 1; }

if command -v python3 >/dev/null 2>&1; then PY=python3
elif command -v python >/dev/null 2>&1 && python -c 'import sys; sys.exit(sys.version_info[0] < 3)' 2>/dev/null; then PY=python
else PY=""; fi

if [ -n "$PY" ]; then
  exec "$PY" - "$ROOT" <<'PYEOF'
import json, os, re, sys, glob
root = sys.argv[1]
def rd(p):
    try:
        with open(os.path.join(root, p), encoding="utf-8", errors="ignore") as f:
            return f.read()
    except Exception:
        return None
def jload(p):
    t = rd(p)
    try:
        return json.loads(t) if t else None
    except Exception:
        return None
out = {"root": os.path.abspath(root)}
cj = jload("composer.json") or {}
lock = jload("composer.lock") or {}
pkgs = {p["name"]: p.get("version") for p in (lock.get("packages", []) + lock.get("packages-dev", []))}
out["isPimcore"] = "pimcore/pimcore" in pkgs or "pimcore/pimcore" in (cj.get("require") or {})
out["pimcore"] = pkgs.get("pimcore/pimcore") or (cj.get("require") or {}).get("pimcore/pimcore")
out["pimcoreSource"] = "composer.lock" if "pimcore/pimcore" in pkgs else ("composer.json constraint" if out["pimcore"] else None)
out["symfony"] = pkgs.get("symfony/framework-bundle")
out["phpRequire"] = (cj.get("require") or {}).get("php")
out["phpPlatform"] = ((cj.get("config") or {}).get("platform") or {}).get("php")
# PHP: composer.json may not pin it. Fall back to what Pimcore itself requires, then the CLI.
_pp = next((x for x in (lock.get("packages", []) + lock.get("packages-dev", [])) if x.get("name") == "pimcore/pimcore"), None)
out["phpPimcoreConstraint"] = ((_pp or {}).get("require") or {}).get("php")
try:
    import subprocess
    _v = subprocess.run(["php", "-r", "echo PHP_VERSION;"], capture_output=True, text=True, timeout=5).stdout.strip()
except Exception:
    _v = ""
out["phpCli"] = _v or None
out["phpNote"] = None if (out["phpRequire"] or out["phpPlatform"]) else "composer.json pins no PHP version; use phpPimcoreConstraint as the supported range and phpCli as the host PHP. The app may run a different PHP in Docker."
out["doctrineOrm"] = pkgs.get("doctrine/orm")
out["pimcorePackages"] = {k: v for k, v in sorted(pkgs.items()) if k.startswith("pimcore/") and k != "pimcore/pimcore"}
interesting = ["symfony/messenger", "codeception/codeception", "phpunit/phpunit", "phpstan/phpstan",
               "vimeo/psalm", "friendsofphp/php-cs-fixer", "squizlabs/php_codesniffer", "symplify/easy-coding-standard",
               "phpoffice/phpspreadsheet", "league/flysystem-sftp-v3", "phpseclib/phpseclib", "guzzlehttp/guzzle",
               "symfony/http-client", "elasticsearch/elasticsearch", "opensearch-project/opensearch-php"]
out["otherPackages"] = {k: pkgs[k] for k in interesting if k in pkgs}
bundles = rd("config/bundles.php") or ""
out["enabledBundles"] = sorted(set(re.findall(r"([A-Za-z0-9_\\\\]+Bundle)::class", bundles)))
out["customBundleDirs"] = sorted(d for d in glob.glob(os.path.join(root, "bundles", "*")) if os.path.isdir(d))
out["customBundleDirs"] = [os.path.relpath(d, root) for d in out["customBundleDirs"]]
out["classDefinitions"] = sorted(os.path.basename(p)[11:-4] for p in glob.glob(os.path.join(root, "var/classes/definition_*.php")))
out["fieldCollections"] = len(glob.glob(os.path.join(root, "var/classes/fieldcollections/*.php")))
out["objectBricks"] = len(glob.glob(os.path.join(root, "var/classes/objectbricks/*.php")))
wf = [p for p in glob.glob(os.path.join(root, "config/**/*.y*ml"), recursive=True) if "workflows:" in (rd(os.path.relpath(p, root)) or "")]
out["workflowConfigs"] = [os.path.relpath(p, root) for p in wf]
compose = [f for f in ("docker-compose.yaml", "docker-compose.yml", "compose.yaml", "compose.yml") if os.path.exists(os.path.join(root, f))]
out["runtime"] = {"dockerCompose": compose, "ddev": os.path.isdir(os.path.join(root, ".ddev")),
                  "lando": os.path.exists(os.path.join(root, ".lando.yml"))}
if compose:
    txt = rd(compose[0]) or ""
    out["runtime"]["composeServices"] = re.findall(r"^\s{2}([a-zA-Z0-9_-]+):\s*$", txt, re.M)
tests = {}
for name in ("codeception.yml", "codeception.dist.yml", "phpunit.xml", "phpunit.xml.dist", "phpstan.neon", "phpstan.neon.dist",
             "psalm.xml", ".php-cs-fixer.php", ".php-cs-fixer.dist.php", "phpcs.xml", "phpcs.xml.dist", "ecs.php", "playwright.config.ts", "playwright.config.js"):
    if os.path.exists(os.path.join(root, name)):
        tests[name] = True
out["qualityTools"] = sorted(tests)
out["testSuites"] = sorted(os.path.basename(p) for p in glob.glob(os.path.join(root, "tests/*.suite.yml")))
out["instructionFiles"] = [f for f in ("CLAUDE.md", "AGENTS.md", ".claude/CLAUDE.md", "CONTRIBUTING.md") if os.path.exists(os.path.join(root, f))]
out["migrationsDirs"] = [d for d in ("src/Migrations", "migrations") if os.path.isdir(os.path.join(root, d))]
major = None
if out["pimcore"]:
    m = re.search(r"(\d+)", str(out["pimcore"]))
    major = int(m.group(1)) if m else None
out["pimcoreMajor"] = major
notes = []
if out["isPimcore"] and "pimcore/pimcore" not in pkgs:
    notes.append("composer.lock missing or has no pimcore/pimcore: version is only a constraint, run composer install or read vendor/pimcore/pimcore/composer.json")
if major and major >= 11 and "pimcore/admin-ui-classic-bundle" not in pkgs:
    notes.append("no admin-ui-classic-bundle in composer.lock: check whether the project uses Pimcore Studio or no admin UI")
out["notes"] = notes
print(json.dumps(out, indent=1))
PYEOF
fi

# Fallback without Python: grep-based, less detail.
ver() { grep -A3 "\"name\": \"$1\"" composer.lock 2>/dev/null | grep '"version"' | head -1 | sed 's/.*"version": "\([^"]*\)".*/\1/'; }
printf '{\n "root": "%s",\n "pimcore": "%s",\n "symfony": "%s",\n "adminUiClassic": "%s",\n "dockerCompose": %s,\n "instructionFiles": "%s",\n "note": "python not found: limited detection"\n}\n' \
  "$PWD" "$(ver pimcore/pimcore)" "$(ver symfony/framework-bundle)" "$(ver pimcore/admin-ui-classic-bundle)" \
  "$( [ -f docker-compose.yaml ] || [ -f docker-compose.yml ] || [ -f compose.yaml ] && echo true || echo false)" \
  "$(ls CLAUDE.md AGENTS.md 2>/dev/null | tr '\n' ' ')"
