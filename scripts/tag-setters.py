#!/usr/bin/env python3
import re, os

ROOT = "/home/ubuntu/nephio-packages"

def load(p):
    with open(p, encoding="utf-8") as f:
        return f.read()

def save(p, s):
    with open(p, "w", encoding="utf-8") as f:
        f.write(s)

def tag_line(content, exact_line, setter, count=None):
    """Append '  # kpt-set: ${setter}' to every line that equals exact_line (ignoring trailing whitespace),
    but only if not already tagged."""
    pattern = re.compile(r"^(?P<line>[ \t]*" + re.escape(exact_line.strip()) + r")[ \t]*$", re.MULTILINE)
    def repl(m):
        return m.group("line") + f"  # kpt-set: ${{{setter}}}"
    new, n = pattern.subn(repl, content)
    if count is not None and n != count:
        raise SystemExit(f"expected {count} matches for {exact_line!r}, got {n}")
    return new, n

def insert_namespace_after_name(content, name_line, namespace_value="5gcore"):
    """Insert a 'namespace: <value> # kpt-set: ${namespace}' line right after the given 'name: X' line,
    matching its indentation."""
    pattern = re.compile(r"^(?P<indent>[ \t]*)" + re.escape(name_line.strip()) + r"[ \t]*$", re.MULTILINE)
    def repl(m):
        indent = m.group("indent")
        return m.group(0) + f"\n{indent}namespace: {namespace_value} # kpt-set: ${{namespace}}"
    new, n = pattern.subn(repl, content)
    if n != 1:
        raise SystemExit(f"expected 1 match for {name_line!r}, got {n}")
    return new

# ---------------- Package 1: free5gc-5gcore-others ----------------
P1 = f"{ROOT}/free5gc-5gcore-others/resources"
for fname in os.listdir(P1):
    fp = os.path.join(P1, fname)
    c = load(fp)
    c, _ = tag_line(c, "namespace: 5gcore", "namespace")
    save(fp, c)

image_map_1 = {
    "10-mongodb.yaml": ("image: docker.io/bitnami/mongodb:latest", "image-mongodb"),
    "20-nrf.yaml": ("image: free5gc/nrf:v4.0.1", "image-nrf"),
    "21-udr.yaml": ("image: free5gc/udr:v4.0.1", "image-udr"),
    "22-udm.yaml": ("image: free5gc/udm:v4.0.1", "image-udm"),
    "23-ausf.yaml": ("image: free5gc/ausf:v4.0.1", "image-ausf"),
    "24-pcf.yaml": ("image: free5gc/pcf:v4.0.1", "image-pcf"),
    "25-nssf.yaml": ("image: free5gc/nssf:v4.0.1", "image-nssf"),
    "26-chf.yaml": ("image: free5gc/chf:v4.0.1", "image-chf"),
    "27-nef.yaml": ("image: free5gc/nef:v4.0.1", "image-nef"),
    "28-dbpython.yaml": ("image: towards5gs/free5gc-dbpython:latest", "image-dbpython"),
    "30-webui.yaml": ("image: free5gc/webui:v4.0.1", "image-webui"),
}
for fname, (line, setter) in image_map_1.items():
    fp = os.path.join(P1, fname)
    c = load(fp)
    c, n = tag_line(c, line, setter, count=1)
    save(fp, c)

for fname, setter in [("01-pv-cert.yaml", "nfs-server"), ("02-pv-mongo.yaml", "nfs-server")]:
    fp = os.path.join(P1, fname)
    c = load(fp)
    c, n = tag_line(c, "server: 192.168.10.10", setter, count=1)
    save(fp, c)

# ---------------- Package 2: free5gc-amf-smf-upf ----------------
P2 = f"{ROOT}/free5gc-amf-smf-upf/resources"
for fname in ["10-amf.yaml", "20-smf.yaml"]:
    fp = os.path.join(P2, fname)
    c = load(fp)
    c, _ = tag_line(c, "namespace: 5gcore", "namespace")
    save(fp, c)

# UPF resources currently have no namespace field -> insert one, tagged
insert_specs = {
    "30-upf-configmap.yaml": "name: config-upf-configmap",
    "31-upf-session-manager-configmap.yaml": "name: session-manager-configmap",
    "32-upf-pod.yaml": "name: upf-test-pod",
    "33-upf-n3-nad.yaml": "name: n3-conf",
    "34-upf-n4-nad.yaml": "name: n4-conf",
    "35-upf-n6-nad.yaml": "name: n6-conf",
}
for fname, name_line in insert_specs.items():
    fp = os.path.join(P2, fname)
    c = load(fp)
    c = insert_namespace_after_name(c, name_line)
    save(fp, c)

image_map_2 = {
    "10-amf.yaml": ("image: free5gc/amf:v4.0.0", "image-amf"),
    "20-smf.yaml": ("image: kiemtcb/smf:v4.0.0-sdn", "image-smf"),
    "32-upf-pod.yaml": ("image: docker.io/kiemtcb/upf-test:nextmn-test-not-debug", "image-upf"),
}
for fname, (line, setter) in image_map_2.items():
    fp = os.path.join(P2, fname)
    c = load(fp)
    c, n = tag_line(c, line, setter, count=1)
    save(fp, c)

# ---------------- Package 3: 5g-controllers ----------------
P3 = f"{ROOT}/5g-controllers/resources"

# fix enipool-manager image to match the currently-live deployed tag
fp = os.path.join(P3, "30-enipool-manager.yaml")
c = load(fp)
c = c.replace(
    "image: kiepdoden123/upf-manager:dynamic-nad-v1",
    "image: kiepdoden123/upf-manager:hybrid-host-device-v1",
)
save(fp, c)

ns_map_3 = {
    "10-agent.yaml": ("agent-system", "agent-namespace"),
    "20-migrate-controller.yaml": ("migrate-system", "migrate-namespace"),
    "30-enipool-manager.yaml": ("enipool-system", "enipool-namespace"),
}
for fname, (ns_value, setter) in ns_map_3.items():
    fp = os.path.join(P3, fname)
    c = load(fp)
    # namespace fields look like "namespace: agent-system" (2 or 4 space indent) - tag all occurrences
    pattern = re.compile(r"^([ \t]*namespace: " + re.escape(ns_value) + r")[ \t]*$", re.MULTILINE)
    c = pattern.sub(lambda m: m.group(1) + f"  # kpt-set: ${{{setter}}}", c)
    save(fp, c)

image_map_3 = {
    "10-agent.yaml": ("image: kiemtcb/controller-migrate:agent", "image-agent"),
    "20-migrate-controller.yaml": ("image: kiemtcb/controller-migrate:checkpoint-restore-v1", "image-migrate-controller"),
    "30-enipool-manager.yaml": ("image: kiepdoden123/upf-manager:hybrid-host-device-v1", "image-enipool-manager"),
}
for fname, (line, setter) in image_map_3.items():
    fp = os.path.join(P3, fname)
    c = load(fp)
    c, n = tag_line(c, line, setter, count=1)
    save(fp, c)

fp = os.path.join(P3, "30-enipool-manager.yaml")
c = load(fp)
c, n = tag_line(c, 'value: "us-east-2"', "aws-region", count=1)
c, n = tag_line(c, 'value: "91414a5d-9d4e-4b1a-8de6-d0a95a6d0490"', "azure-subscription-id", count=1)
c, n = tag_line(c, 'value: "rg-upf-migrate-azure"', "azure-resource-group", count=1)
c, n = tag_line(c, 'value: "eastus2"', "azure-location", count=1)
save(fp, c)

print("tagging complete")
