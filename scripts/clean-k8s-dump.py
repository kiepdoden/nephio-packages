#!/usr/bin/env python3
"""Strip runtime/bookkeeping fields from a `kubectl get ... -o yaml` List dump
and write one YAML doc per object into an output directory, named
<kind-lower>-<name>.yaml, ready to be used as static kpt package resources."""
import sys, os
import yaml

IN_PATH, OUT_DIR = sys.argv[1], sys.argv[2]
os.makedirs(OUT_DIR, exist_ok=True)

STRIP_META = [
    "creationTimestamp", "resourceVersion", "uid", "generation",
    "managedFields", "selfLink", "ownerReferences",
]
STRIP_ANNOTATIONS = [
    "kubectl.kubernetes.io/last-applied-configuration",
    "deployment.kubernetes.io/revision",
]

def clean(obj):
    obj.pop("status", None)
    md = obj.get("metadata", {})
    for k in STRIP_META:
        md.pop(k, None)
    ann = md.get("annotations")
    if ann:
        for k in STRIP_ANNOTATIONS:
            ann.pop(k, None)
        if not ann:
            md.pop("annotations", None)
    if "spec" in obj and isinstance(obj["spec"], dict):
        obj["spec"].pop("clusterIP", None)
        obj["spec"].pop("clusterIPs", None)
    return obj

with open(IN_PATH, encoding="utf-8") as f:
    doc = yaml.safe_load(f)

items = doc.get("items", [doc]) if isinstance(doc, dict) and doc.get("kind") == "List" else [doc]
for item in items:
    item = clean(item)
    kind = item["kind"].lower()
    name = item["metadata"]["name"]
    out_path = os.path.join(OUT_DIR, f"{kind}-{name}.yaml")
    with open(out_path, "w", encoding="utf-8") as f:
        yaml.dump(item, f, default_flow_style=False, sort_keys=False, width=100000)
    print(out_path)
