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
               "data-modelling", "admin-ui-development", "object-lifecycle", "integration-development",
               "data-import-export", "performance-optimization", "security-best-practices", "testing-validation",
               "code-review", "upgrade-migration", "deployment-release"]
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
    if name in ("pimcore", "pimcore-setup"):
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
known_docs = {"SKILL", "CLAUDE", "README", "orchestration", "output-formats", "scenarios"}
skip_prefix = ("pimcore-engineering", "pimcore-environment", "pimcore-setup", "pimcore-toolkit",
               "pimcore-install", "pimcore-doctor", "pimcore-architecture", "pimcore-app")
for p in ["skills/pimcore/SKILL.md", "skills/pimcore-setup/SKILL.md", "references/orchestration.md",
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
           "skills/pimcore-setup/scripts/gen-secrets.sh", "skills/pimcore-setup/scripts/health-check.sh"]
for s in scripts:
    r = subprocess.run(["bash", "-n", os.path.join(ROOT, s)], capture_output=True)
    check(r.returncode == 0, f"{s}: bash syntax error {r.stderr.decode()[:200]}")
    check(os.access(os.path.join(ROOT, s), os.X_OK), f"{s}: not executable")
for s in ["detect-env.ps1", "gen-secrets.ps1", "health-check.ps1"]:
    check(os.path.exists(os.path.join(ROOT, "skills/pimcore-setup/scripts", s)), f"{s} missing")

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
