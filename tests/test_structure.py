#!/usr/bin/env python3
"""Structure tests for the Pimcore Engineering Toolkit plugin.

Checks frontmatter, names, module references, agent-to-skill mapping,
section template, script syntax and writing style. Standard library only.
Usage: python3 tests/test_structure.py   (exit 0 when everything passes)
"""
import json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FAILS = []
PASSES = 0


def check(cond, msg):
    global PASSES
    if cond:
        PASSES += 1
    else:
        FAILS.append(msg)


def read(p):
    with open(os.path.join(ROOT, p), encoding="utf-8") as f:
        return f.read()


def frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None
    fm = {}
    for line in m.group(1).splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip().strip('"')
    return fm


DEV_MODULES = ["requirements-analysis", "solution-planning", "pimcore-architecture", "backend-development",
               "data-modelling", "admin-ui-development", "studio-ui-development", "studio-backend-extension",
               "object-lifecycle", "integration-development",
               "data-import-export", "performance-optimization", "security-best-practices", "testing-validation",
               "code-review", "upgrade-migration", "platform-2026-upgrade", "deployment-release"]
SETUP_MODULES = ["environment-detection", "docker-environment", "native-environment", "pimcore-installation",
                 "database-provisioning", "environment-security", "setup-validation", "environment-troubleshooting"]
AGENTS = {
    "pimcore-solution-architect": "pimcore-toolkit:pimcore-engineering",
    "pimcore-developer": "pimcore-toolkit:pimcore-engineering",
    "pimcore-data-modeler": "pimcore-toolkit:pimcore-engineering",
    "pimcore-debugger": "pimcore-toolkit:pimcore-engineering",
    "pimcore-integration-specialist": "pimcore-toolkit:pimcore-engineering",
    "pimcore-code-reviewer": "pimcore-toolkit:pimcore-engineering",
    "pimcore-qa-engineer": "pimcore-toolkit:pimcore-engineering",
    "pimcore-upgrade-specialist": "pimcore-toolkit:pimcore-engineering",
    "pimcore-environment-setup": "pimcore-toolkit:pimcore-environment",
}
READ_ONLY = {"pimcore-solution-architect", "pimcore-data-modeler", "pimcore-debugger",
             "pimcore-integration-specialist", "pimcore-code-reviewer", "pimcore-upgrade-specialist"}
SECTIONS = ["## Purpose and scope", "## Inspect", "## Workflow", "## Best practices", "## Common mistakes",
            "## Version notes", "## Example", "## Validation checklist", "## Expected output"]
BANNED = [chr(0x2014), "robust", "seamless", "leverage", "delve", "comprehensive", "streamline", "elevate"]

# 1. plugin manifest
pj = json.loads(read(".claude-plugin/plugin.json"))
check(pj.get("name") == "pimcore-toolkit", "plugin.json name must be pimcore-toolkit")
check(os.path.exists(os.path.join(ROOT, ".claude-plugin/marketplace.json")), "marketplace.json missing")

# 2. skills
skills = {
    "pimcore": {"disable-model-invocation": "true"},
    "pimcore-setup": {"disable-model-invocation": "true"},
    "pimcore-doctor": {"disable-model-invocation": "true"},
    "pimcore-review": {"disable-model-invocation": "true"},
    "pimcore-engineering": {"user-invocable": "false"},
    "pimcore-environment": {"user-invocable": "false"},
}
for name, need in skills.items():
    path = f"skills/{name}/SKILL.md"
    if not os.path.exists(os.path.join(ROOT, path)):
        check(False, f"{path} missing")
        continue
    fm = frontmatter(read(path)) or {}
    check(fm.get("name") == name, f"{path}: name must be {name}")
    check(len(fm.get("description", "")) > 40, f"{path}: description too short")
    for k, v in need.items():
        check(fm.get(k) == v, f"{path}: {k} must be {v}")
    if name in ("pimcore", "pimcore-setup", "pimcore-doctor", "pimcore-review"):
        check("argument-hint" in fm, f"{path}: argument-hint missing")
        check("$ARGUMENTS" in read(path), f"{path}: must use $ARGUMENTS")

# 3. modules: present, indexed, sectioned
for skill, mods in (("pimcore-engineering", DEV_MODULES), ("pimcore-environment", SETUP_MODULES)):
    index = read(f"skills/{skill}/SKILL.md")
    found = sorted(f[:-3] for f in os.listdir(os.path.join(ROOT, f"skills/{skill}/modules")) if f.endswith(".md"))
    check(sorted(mods) == found, f"{skill}: modules on disk {found} differ from expected")
    for m in mods:
        check(f"{m}.md" in index, f"{skill}/SKILL.md does not index {m}.md")
        p = f"skills/{skill}/modules/{m}.md"
        if os.path.exists(os.path.join(ROOT, p)):
            body = read(p)
            for s in SECTIONS:
                check(s in body, f"{p}: missing section '{s}'")
            check("**Use when:**" in body and "**Do not use when:**" in body, f"{p}: missing use/do-not-use lines")

# 4. agents
for name, skill in AGENTS.items():
    p = f"agents/{name}.md"
    if not os.path.exists(os.path.join(ROOT, p)):
        check(False, f"{p} missing")
        continue
    fm = frontmatter(read(p)) or {}
    check(fm.get("name") == name, f"{p}: name mismatch")
    check(fm.get("skills") == skill, f"{p}: skills must be {skill}")
    check(fm.get("model") in ("opus", "sonnet", "haiku", "inherit"), f"{p}: bad model")
    tools = [t.strip() for t in fm.get("tools", "").split(",")]
    if name in READ_ONLY:
        check("Write" not in tools and "Edit" not in tools, f"{p}: read-only agent has write tools")
    check("Agent" not in tools and "Task" not in tools, f"{p}: subagents cannot start agents")
on_disk = sorted(f[:-3] for f in os.listdir(os.path.join(ROOT, "agents")) if f.endswith(".md"))
check(on_disk == sorted(AGENTS), f"agents on disk {on_disk} differ from expected")

# 5. module and agent names referenced in commands, references and agents exist
all_mods = set(DEV_MODULES + SETUP_MODULES)
known_docs = {"SKILL", "CLAUDE", "README", "orchestration", "output-formats", "scenarios", "pimcore-versions"}
skip_prefix = ("pimcore-engineering", "pimcore-environment", "pimcore-setup", "pimcore-toolkit",
               "pimcore-install", "pimcore-doctor", "pimcore-review", "pimcore-architecture", "pimcore-app")
for p in ["skills/pimcore/SKILL.md", "skills/pimcore-setup/SKILL.md", "references/orchestration.md",
          "skills/pimcore-doctor/SKILL.md", "skills/pimcore-review/SKILL.md",
          "skills/pimcore-engineering/SKILL.md", "skills/pimcore-environment/SKILL.md"] + \
         [f"agents/{a}.md" for a in AGENTS]:
    text = read(p)
    for ref in set(re.findall(r"`([a-z-]+)\.md`", text)):
        check(ref in all_mods or ref in known_docs, f"{p}: unknown module {ref}.md")
    for ref in set(re.findall(r"`(pimcore-[a-z-]+)`", text)):
        if ref.startswith(skip_prefix):
            continue
        check(ref in AGENTS, f"{p}: unknown agent {ref}")

# 6. scripts
scripts = ["skills/pimcore/scripts/detect-project.sh", "skills/pimcore-setup/scripts/detect-env.sh",
           "skills/pimcore-setup/scripts/gen-secrets.sh", "skills/pimcore-setup/scripts/health-check.sh",
           "skills/pimcore-setup/scripts/install-prereqs.sh", "skills/pimcore/scripts/scan-platform-impact.sh",
           "skills/pimcore/scripts/enable-auto-update.sh", "skills/pimcore-doctor/scripts/doctor.sh",
           "skills/pimcore-review/scripts/review-scope.sh", "hooks/auto-review.sh"]
for s in scripts:
    r = subprocess.run(["bash", "-n", os.path.join(ROOT, s)], capture_output=True)
    check(r.returncode == 0, f"{s}: bash syntax error {r.stderr.decode()[:200]}")
    check(os.access(os.path.join(ROOT, s), os.X_OK), f"{s}: not executable")
for s in ["detect-env.ps1", "gen-secrets.ps1", "health-check.ps1", "install-prereqs.ps1"]:
    check(os.path.exists(os.path.join(ROOT, "skills/pimcore-setup/scripts", s)), f"{s} missing")


# 6b. detect-project.sh on fixtures: release line and admin UI detection
import tempfile
check(os.path.exists(os.path.join(ROOT, "references/pimcore-versions.md")), "references/pimcore-versions.md missing")


def detect(packages, extra_json=None):
    with tempfile.TemporaryDirectory() as d:
        lock = {"packages": [{"name": n, "version": v} for n, v in packages.items()]}
        with open(os.path.join(d, "composer.lock"), "w") as fh:
            json.dump(lock, fh)
        with open(os.path.join(d, "composer.json"), "w") as fh:
            json.dump({"require": {"pimcore/pimcore": "*"}}, fh)
        r = subprocess.run(["bash", os.path.join(ROOT, "skills/pimcore/scripts/detect-project.sh"), d],
                           capture_output=True, text=True)
        try:
            return json.loads(r.stdout)
        except Exception:
            return {"_error": (r.stdout + r.stderr)[:300]}


fx = {
    "classic11": {"pimcore/pimcore": "v11.4.0", "pimcore/admin-ui-classic-bundle": "v1.5.0", "symfony/framework-bundle": "v6.4.0"},
    "both": {"pimcore/pimcore": "v12.1.0", "pimcore/admin-ui-classic-bundle": "v2.0.0",
             "pimcore/studio-ui-bundle": "v1.0.0", "symfony/framework-bundle": "v7.3.0"},
    "y2026": {"pimcore/pimcore": "2026.1.0", "pimcore/studio-ui-bundle": "2026.1.0", "symfony/framework-bundle": "v7.3.0"},
}
expect = {"classic11": ("classic", False), "both": ("both", False), "y2026": ("studio", True)}
for name, pk in fx.items():
    out = detect(pk)
    check("_error" not in out, f"detect-project fixture {name}: {out.get('_error')}")
    if "_error" in out:
        continue
    ui, year = expect[name]
    check(out.get("adminUi") == ui, f"detect-project {name}: adminUi {out.get('adminUi')} != {ui}")
    check(out.get("yearBased") == year, f"detect-project {name}: yearBased {out.get('yearBased')} != {year}")
    check(bool(out.get("releaseLine")), f"detect-project {name}: releaseLine missing")
    if name != "classic11":
        check(bool(out.get("studioPackages")), f"detect-project {name}: studioPackages empty")

# 6c. scan-platform-impact.sh: rules file and fixture project
import re as _re
RULES_PATH = "skills/pimcore/scripts/platform-impact-rules.json"
check(os.path.exists(os.path.join(ROOT, RULES_PATH)), f"{RULES_PATH} missing")
rules_doc = json.loads(read(RULES_PATH))
ids = [r["id"] for r in rules_doc["rules"]]
check(len(ids) == len(set(ids)), "platform-impact-rules.json: duplicate rule ids")
for r in rules_doc["rules"]:
    rid = r.get("id", "?")
    for key in ("id", "step", "title", "kind", "confidence", "advice", "source"):
        check(bool(r.get(key)), f"rule {rid}: missing {key}")
    check(r.get("step") in rules_doc["steps"], f"rule {rid}: unknown step {r.get('step')}")
    check(r.get("kind") in ("grep", "composer", "composer-constraint"), f"rule {rid}: unknown kind")
    check(r.get("confidence") in ("documented", "heuristic"), f"rule {rid}: bad confidence")
    check(str(r.get("source", "")).startswith("https://docs.pimcore.com/"), f"rule {rid}: source must be an official docs URL")
    for p in r.get("patterns", []) + r.get("excludeLineIf", []):
        try:
            _re.compile(p)
        except _re.error as e:
            check(False, f"rule {rid}: bad regex {p}: {e}")
    if r.get("kind") == "grep":
        check(bool(r.get("files")) and bool(r.get("patterns")), f"rule {rid}: grep rule needs files and patterns")


def scan(files, extra=()):
    with tempfile.TemporaryDirectory() as d:
        for rel, text in files.items():
            p = os.path.join(d, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w") as fh:
                fh.write(text)
        r = subprocess.run(["bash", os.path.join(ROOT, "skills/pimcore/scripts/scan-platform-impact.sh"), d,
                            "--format", "json", *extra], capture_output=True, text=True)
        try:
            return json.loads(r.stdout), r.returncode
        except Exception:
            return {"_error": (r.stdout + r.stderr)[:300]}, r.returncode


proj = {
    "composer.json": json.dumps({"require": {"php": "^8.2", "symfony/console": "^6.4", "geoip2/geoip2": "^2.13"}}),
    "src/A.php": "<?php\nuse Symfony\\Component\\Templating\\EngineInterface;\nclass A implements PimcoreBundleAdminClassicInterface {}\n",
    "src/Clean.php": "<?php\nclass Clean {}\n",
    "public/static/js/a.js": "Ext.define('x', {});\n",
    ".github/workflows/ci.yml": "run: vendor/bin/pimcore-install -n\nrun: vendor/bin/pimcore-install --install-profile x\n",
    "vendor/x/V.php": "<?php class V implements PimcoreBundleAdminClassicInterface {}\n",
    ".claude/worktrees/t1/src/W.php": "<?php class W implements PimcoreBundleAdminClassicInterface {}\n",
}
rep, rc = scan(proj)
check("_error" not in rep and rc == 0, f"scan fixture failed: {rep.get('_error')}")
if "_error" not in rep:
    found = {f["id"]: f for f in rep["findings"]}
    for rid in ("classic-admin-interface", "classic-admin-js", "php-version", "symfony-6",
                "install-without-profile", "templating-engine", "geoip"):
        check(rid in found, f"scan fixture: rule {rid} did not match")
    check(rep.get("readOnly") is True, "scan: readOnly flag missing")
    check(found.get("classic-admin-interface", {}).get("total") == 1, "scan: vendor/ and .claude/worktrees must be skipped")
    check(found.get("install-without-profile", {}).get("total") == 1, "scan: the --install-profile line must not match")
    check(all(m["file"] != "src/Clean.php" for f in rep["findings"] for m in f["matches"]), "scan: clean file matched")
    check(rep["summary"]["filesAffected"] >= 4, "scan: summary filesAffected too low")
rep_clean, _ = scan({"composer.json": json.dumps({"require": {"php": "~8.4"}}), "src/Clean.php": "<?php\nclass Clean {}\n"})
check(rep_clean.get("summary", {}).get("totalMatches") == 0, f"scan: clean project must have no matches: {rep_clean.get('summary')}")
bad, bad_rc = scan({"composer.json": "{}"}, extra=("--to", "bogus"))
check(bad_rc == 2, "scan: unknown --to must exit 2")

# 6d. step order, aliases, and the 2024/2025 rules
check(rules_doc["steps"] == ["2024", "2025", "2026"], f"rules steps must be 2024, 2025, 2026: {rules_doc['steps']}")
for alias, target in rules_doc.get("aliases", {}).items():
    check(target in rules_doc["steps"], f"alias {alias} points to unknown step {target}")
check(rules_doc.get("aliases", {}).get("12") == "2025", "rules aliases: 12 must map to 2025")
check(len(rules_doc["rules"]) >= 50, f"expected the researched rule set, got {len(rules_doc['rules'])} rules")
by_step = {s: [r for r in rules_doc["rules"] if r["step"] == s] for s in rules_doc["steps"]}
check(all(by_step[s] for s in by_step), "every step needs at least one rule")

proj2 = {
    "composer.json": json.dumps({"require": {
        "php": "~8.4", "doctrine/dbal": "^3.6", "gotenberg/gotenberg-php": "^1.1",
        "pimcore/admin-ui-classic-bundle": "^1.0", "pimcore/web-to-print-bundle": "^1.0",
        "pimcore/newsletter-bundle": "^1.0", "pimcore/advanced-object-search": "^1.0"}}),
    "templates/a.html.twig": "{{ pimcore_block('x') }}\n{{ pimcore_cache('k') }}\n",
    "src/B.php": ("<?php\nuse Doctrine\\Common\\Annotations\\Reader;\nuse Pimcore\\Db\\Helper;\n"
                  "Helper::quoteInto('a = ?', 1);\n$f->setIndex(null);\nnew CsvFormulaFormatter();\n"
                  "Serialize::unserialize($x);\nSerialize::unserialize($x, ['A']);\n"
                  "use Pimcore\\Event\\Model\\Asset\\ResolveUploadTargetEvent;\n"),
    "config/packages/security.yaml": "security:\n  enable_authenticator_manager: true\n",
    "docker/Dockerfile": "FROM php:8.4-fpm\nRUN apt-get install -y chromium\n",
    "src/Clean.php": "<?php\nclass Clean {}\n",
}
r24, rc24 = scan(proj2, extra=("--to", "2024"))
r12, rc12 = scan(proj2, extra=("--to", "12"))
r25, _ = scan(proj2, extra=("--to", "2025"))
r26, _ = scan(proj2, extra=("--to", "2026"))
check(rc24 == 0 and rc12 == 0 and "_error" not in r24 and "_error" not in r12, f"scan proj2 failed: {r24.get('_error')} {r12.get('_error')}")
if "_error" not in r24 and "_error" not in r12 and "_error" not in r25 and "_error" not in r26:
    f24 = {f["id"]: f for f in r24["findings"]}
    f12 = {f["id"]: f for f in r12["findings"]}
    f26 = {f["id"]: f for f in r26["findings"]}
    for rid in ("twig-pimcore-block", "twig-pimcore-cache", "upload-target-event"):
        check(rid in f24, f"scan --to 2024: rule {rid} did not match")
    for rid in ("authenticator-manager", "doctrine-annotations", "db-helper", "set-index-null",
                "csv-formula-formatter", "dbal-v3", "gotenberg-v1", "classic-bundle-licence",
                "enterprise-only-bundles", "deprecated-bundles-2025-4", "headless-chrome", "serialize-unserialize"):
        check(rid in f12, f"scan --to 12: rule {rid} did not match")
    for rid in ("authenticator-manager", "dbal-v3", "db-helper"):
        check(rid not in f24, f"scan --to 2024 must not include 2025 rule {rid}")
    check("discontinued-bundles" not in f12, "scan --to 12 must not include 2026 rule discontinued-bundles")
    check("discontinued-bundles" in f26, "scan --to 2026: discontinued-bundles did not match")
    check(f12.get("serialize-unserialize", {}).get("total") == 1, "scan: Serialize::unserialize with allowed classes must not match")
    check(r12["summary"] == r25["summary"], "scan: --to 12 must equal --to 2025")
    check(all(m["file"] != "src/Clean.php" for f in r26["findings"] for m in f["matches"]), "scan proj2: clean file matched")

# the script must work when called by a relative path with a relative project root
rel = subprocess.run(["bash", "skills/pimcore/scripts/scan-platform-impact.sh", "references", "--format", "json"],
                     cwd=ROOT, capture_output=True, text=True)
try:
    rel_rep = json.loads(rel.stdout)
    check(rel.returncode == 0 and rel_rep["root"].endswith("/references"), "scan: relative script path and root must work")
except Exception:
    check(False, f"scan: relative path run failed: {(rel.stdout + rel.stderr)[:200]}")

# 6e. hooks: valid JSON, both events point at the auto-review script
hk = json.loads(read("hooks/hooks.json"))
for ev, mode in (("SessionStart", "baseline"), ("Stop", "stop")):
    cmds = [h.get("command", "") for g in hk.get("hooks", {}).get(ev, []) for h in g.get("hooks", [])]
    check(any("${CLAUDE_PLUGIN_ROOT}/hooks/auto-review.sh" in c and c.endswith(mode) for c in cmds),
          f"hooks.json: {ev} must run auto-review.sh {mode}")

# 6f. auto-review hook and review-scope on a throwaway git repository
GENV = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@example.invalid",
            GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@example.invalid", PIMCORE_AUTO_REVIEW="1")
HOOK = os.path.join(ROOT, "hooks/auto-review.sh")
SCOPE = os.path.join(ROOT, "skills/pimcore-review/scripts/review-scope.sh")


def hook(d, mode, active=False):
    payload = json.dumps({"cwd": d, "stop_hook_active": active})
    r = subprocess.run(["bash", HOOK, mode], input=payload, capture_output=True, text=True, env=GENV)
    return r.returncode, r.stdout.strip()


with tempfile.TemporaryDirectory() as d:
    def w(rel, text):
        p = os.path.join(d, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w") as fh:
            fh.write(text)
    w("composer.json", json.dumps({"require": {"pimcore/pimcore": "^11.0"}}))
    w("src/A.php", "<?php\nclass A {}\n")
    for c in (["init", "-q", "-b", "feature/test"], ["add", "-A"], ["commit", "-q", "-m", "init"]):
        subprocess.run(["git", *c], cwd=d, env=GENV, capture_output=True)
    hook(d, "baseline")
    check(hook(d, "stop") == (0, ""), "auto-review: no changes must not block")
    w("README.txt", "notes\n")
    check(hook(d, "stop")[1] == "", "auto-review: a non-code change must not block")
    w("src/A.php", "<?php\nclass A { public function x() {} }\n")
    rc, out = hook(d, "stop")
    try:
        dec = json.loads(out)
    except Exception:
        dec = {}
    check(rc == 0 and dec.get("decision") == "block" and "pimcore-review" in dec.get("reason", ""),
          f"auto-review: a code change must ask for a review: {out[:200]}")
    check(hook(d, "stop")[1] == "", "auto-review: the same changes must not be reviewed twice")
    w("src/B.php", "<?php\nclass B {}\n")
    check(hook(d, "stop", active=True)[1] == "", "auto-review: stop_hook_active must never block (no loop)")
    w("src/C.php", "<?php\nclass C {}\n")
    off = subprocess.run(["bash", HOOK, "stop"], input=json.dumps({"cwd": d}), capture_output=True, text=True,
                         env=dict(GENV, PIMCORE_AUTO_REVIEW="0"))
    check(off.stdout.strip() == "", "auto-review: PIMCORE_AUTO_REVIEW=0 must turn it off")
    subprocess.run(["git", "config", "pimcore.autoReview", "false"], cwd=d, env=GENV)
    check(hook(d, "stop")[1] == "", "auto-review: git config pimcore.autoReview false must turn it off")

    sc = subprocess.run(["bash", SCOPE, d], capture_output=True, text=True, env=GENV)
    try:
        scope = json.loads(sc.stdout)
        paths = {f["path"]: f["status"] for f in scope["files"]}
        check(paths.get("src/A.php") == "M" and paths.get("src/B.php") == "A", f"review-scope: wrong files {paths}")
        check("README.txt" not in paths, "review-scope: non-code files must be skipped")
    except Exception:
        check(False, f"review-scope changes mode failed: {(sc.stdout + sc.stderr)[:200]}")
    sa = subprocess.run(["bash", SCOPE, d, "--all"], capture_output=True, text=True, env=GENV)
    try:
        allj = json.loads(sa.stdout)
        check(allj["mode"] == "all" and any(g["folder"] == "src" for g in allj["groups"]), "review-scope --all: groups missing")
    except Exception:
        check(False, f"review-scope --all failed: {(sa.stdout + sa.stderr)[:200]}")
    bad = subprocess.run(["bash", SCOPE, d, "--bogus"], capture_output=True, text=True)
    check(bad.returncode == 2, "review-scope: unknown option must exit 2")

with tempfile.TemporaryDirectory() as d:
    hook_out = hook(d, "stop")
    check(hook_out == (0, ""), "auto-review: outside a git repository it must do nothing")

# 6g. enable-auto-update.sh on a scratch config folder (never the real ~/.claude)
EAU = os.path.join(ROOT, "skills/pimcore/scripts/enable-auto-update.sh")
with tempfile.TemporaryDirectory() as cfg:
    env = {k: v for k, v in os.environ.items()
           if k not in ("DISABLE_AUTOUPDATER", "DISABLE_UPDATES", "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC")}
    env["CLAUDE_CONFIG_DIR"] = cfg
    with open(os.path.join(cfg, "settings.json"), "w") as fh:
        json.dump({"theme": "dark"}, fh)
    r = subprocess.run(["bash", EAU], capture_output=True, text=True, env=env)
    st = json.loads(open(os.path.join(cfg, "settings.json")).read()) if r.returncode == 0 else {}
    mk = st.get("extraKnownMarketplaces", {}).get("pimcore-toolkit", {})
    check(mk.get("autoUpdate") is True and st.get("theme") == "dark", f"enable-auto-update: on failed: {r.stdout[:200]}")
    check(mk.get("source", {}).get("repo") == "muhammed-rishanK/pimcore-toolkit", "enable-auto-update: wrong source repo")
    r = subprocess.run(["bash", EAU, "--check"], capture_output=True, text=True, env=env)
    check('"on"' in r.stdout, f"enable-auto-update --check must report on: {r.stdout[:200]}")
    subprocess.run(["bash", EAU, "--off"], capture_output=True, text=True, env=env)
    st = json.loads(open(os.path.join(cfg, "settings.json")).read())
    check(st["extraKnownMarketplaces"]["pimcore-toolkit"]["autoUpdate"] is False, "enable-auto-update --off failed")
    r = subprocess.run(["bash", EAU, "--bogus"], capture_output=True, text=True, env=env)
    check(r.returncode == 2, "enable-auto-update: unknown option must exit 2")

# 6h. install-prereqs --check reports how to call docker
r = subprocess.run(["bash", os.path.join(ROOT, "skills/pimcore-setup/scripts/install-prereqs.sh"), "--check"],
                   capture_output=True, text=True, timeout=120)
try:
    ip = json.loads(r.stdout)
    check("status" in ip and "dockerCmd" in ip, f"install-prereqs --check: status or dockerCmd missing: {list(ip)}")
except Exception:
    check(False, f"install-prereqs --check: not JSON: {(r.stdout + r.stderr)[:200]}")

# 7. writing style over shipped files
for dirpath, _, files in os.walk(ROOT):
    if "/.git" in dirpath or dirpath.endswith("/tests"):
        continue
    for f in files:
        if not f.endswith((".md", ".sh", ".ps1", ".json")):
            continue
        rel = os.path.relpath(os.path.join(dirpath, f), ROOT)
        low = read(rel).lower()
        for w in BANNED:
            check(w not in low, f"{rel}: banned word or em-dash '{w}'")

print(f"{PASSES} checks passed, {len(FAILS)} failed")
for f in FAILS:
    print("FAIL:", f)
sys.exit(1 if FAILS else 0)
