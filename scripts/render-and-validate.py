#!/usr/bin/env python3
"""No docker/kpt-fn-image available on this host, so emulate apply-setters
(simple '<value> # kpt-set: ${name}' textual substitution) ourselves and
validate the rendered YAML both for syntax and (best-effort) via
`kubectl apply --dry-run=client`."""
import os, re, subprocess, sys, yaml

ROOT = "/home/ubuntu/nephio-packages"
PACKAGES = ["free5gc-5gcore-others", "free5gc-amf-smf-upf", "5g-controllers", "upf-migrate-manager", "karmada-control-plane"]

SETTER_RE = re.compile(r"^(?P<prefix>\s*\S.*?:\s*)(?P<value>\S.*?)(?P<comment>\s*#\s*kpt-set:\s*\$\{(?P<name>[\w-]+)\})\s*$")

def load_setters(pkg_dir):
    with open(os.path.join(pkg_dir, "setters.yaml"), encoding="utf-8") as f:
        doc = yaml.safe_load(f)
    return doc["data"]

def render_file(path, setters):
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()
    out = []
    for line in lines:
        m = SETTER_RE.match(line.rstrip("\n"))
        if m:
            name = m.group("name")
            if name not in setters:
                print(f"  WARN: setter {name} referenced in {path} not found in setters.yaml")
                out.append(line)
                continue
            new_val = str(setters[name])
            # keep quoting style if original value was quoted
            orig_val = m.group("value")
            if orig_val.startswith('"') and orig_val.endswith('"'):
                new_val = f'"{new_val}"'
            newline = f'{m.group("prefix")}{new_val}{m.group("comment")}\n'
            out.append(newline)
        else:
            out.append(line)
    return "".join(out)

exit_code = 0
for pkg in PACKAGES:
    pkg_dir = os.path.join(ROOT, pkg)
    print(f"===== {pkg} =====")
    setters = load_setters(pkg_dir)
    res_dir = os.path.join(pkg_dir, "resources")
    rendered_dir = os.path.join(pkg_dir, "_rendered")
    os.makedirs(rendered_dir, exist_ok=True)
    all_docs = []
    for fname in sorted(os.listdir(res_dir)):
        rendered = render_file(os.path.join(res_dir, fname), setters)
        out_path = os.path.join(rendered_dir, fname)
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(rendered)
        try:
            docs = list(yaml.safe_load_all(rendered))
            all_docs.extend([d for d in docs if d])
        except yaml.YAMLError as e:
            print(f"  YAML PARSE ERROR in {fname}: {e}")
            exit_code = 1
    print(f"  {len(all_docs)} k8s objects parsed OK across {len(os.listdir(res_dir))} files")
    kinds = {}
    for d in all_docs:
        k = d.get("kind", "?")
        kinds[k] = kinds.get(k, 0) + 1
    print(f"  kinds: {kinds}")

    # kubectl dry-run client validation (schema-level, no cluster writes)
    combined = os.path.join(rendered_dir, "_all.yaml")
    with open(combined, "w", encoding="utf-8") as f:
        for fname in sorted(os.listdir(res_dir)):
            with open(os.path.join(rendered_dir, fname), encoding="utf-8") as rf:
                f.write(rf.read())
                f.write("\n---\n")
    r = subprocess.run(
        ["kubectl", "apply", "--dry-run=client", "-f", combined],
        capture_output=True, text=True,
    )
    print("  kubectl dry-run stdout tail:", "\n".join(r.stdout.strip().splitlines()[-5:]))
    if r.returncode != 0:
        print("  kubectl dry-run STDERR:", r.stderr.strip())
        exit_code = 1
    print()

sys.exit(exit_code)
