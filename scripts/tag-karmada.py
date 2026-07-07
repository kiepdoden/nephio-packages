#!/usr/bin/env python3
import re, os

D = "/home/ubuntu/nephio-packages/karmada-control-plane/resources"

def load(p):
    with open(p, encoding="utf-8") as f:
        return f.read()

def save(p, s):
    with open(p, "w", encoding="utf-8") as f:
        f.write(s)

def tag_all(content, exact_line, setter):
    pattern = re.compile(r"^(?P<line>[ \t]*" + re.escape(exact_line.strip()) + r")[ \t]*$", re.MULTILINE)
    return pattern.sub(lambda m: m.group("line") + f"  # kpt-set: ${{{setter}}}", content)

def tag_once(content, exact_line, setter):
    pattern = re.compile(r"^(?P<line>[ \t]*" + re.escape(exact_line.strip()) + r")[ \t]*$", re.MULTILINE)
    new, n = pattern.subn(lambda m: m.group("line") + f"  # kpt-set: ${{{setter}}}", content, count=1)
    if n != 1:
        raise SystemExit(f"expected 1 match for {exact_line!r}, got {n}")
    return new

for fname in os.listdir(D):
    fp = os.path.join(D, fname)
    c = load(fp)
    c = tag_all(c, "namespace: karmada-system", "namespace")
    save(fp, c)

image_map = {
    "deployment-karmada-apiserver.yaml": ("image: registry.k8s.io/kube-apiserver:v1.35.2", "image-karmada-apiserver"),
    "deployment-karmada-aggregated-apiserver.yaml": ("image: docker.io/karmada/karmada-aggregated-apiserver:v1.17.1", "image-karmada-aggregated-apiserver"),
    "deployment-karmada-webhook.yaml": ("image: docker.io/karmada/karmada-webhook:v1.17.1", "image-karmada-webhook"),
    "deployment-karmada-controller-manager.yaml": ("image: docker.io/karmada/karmada-controller-manager:v1.17.1", "image-karmada-controller-manager"),
    "deployment-karmada-scheduler.yaml": ("image: docker.io/karmada/karmada-scheduler:v1.17.1", "image-karmada-scheduler"),
    "deployment-kube-controller-manager.yaml": ("image: registry.k8s.io/kube-controller-manager:v1.35.2", "image-kube-controller-manager"),
    "statefulset-etcd.yaml": ("image: registry.k8s.io/etcd:3.6.6-0", "image-etcd"),
}
for fname, (line, setter) in image_map.items():
    fp = os.path.join(D, fname)
    c = load(fp)
    c = tag_once(c, line, setter)
    save(fp, c)

# etcd hostPath — flag explicitly as a setter so it's obvious this is node-local storage
fp = os.path.join(D, "statefulset-etcd.yaml")
c = load(fp)
c = tag_once(c, "path: /var/lib/karmada-etcd", "etcd-hostpath")
save(fp, c)

print("karmada tagging complete")
