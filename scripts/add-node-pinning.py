#!/usr/bin/env python3
D = "/home/ubuntu/nephio-packages/free5gc-amf-smf-upf/resources"

# ---------------- SMF ----------------
p = f"{D}/20-smf.yaml"
s = open(p, encoding="utf-8").read()

old_affinity = "    spec:\n      affinity: {}\n"
new_affinity = """    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: kubernetes.io/hostname
                    operator: In
                    values:
                      - ip-192-168-10-12 # kpt-set: ${smf-node}
"""
assert old_affinity in s, "SMF affinity marker not found"
s = s.replace(old_affinity, new_affinity, 1)

old_nodesel = "      nodeSelector: {}\n"
new_nodesel = """      nodeSelector:
        kubernetes.io/hostname: ip-192-168-10-12 # kpt-set: ${smf-node}
"""
assert old_nodesel in s, "SMF nodeSelector marker not found"
s = s.replace(old_nodesel, new_nodesel, 1)

open(p, "w", encoding="utf-8").write(s)
print("SMF patched")

# ---------------- UPF ----------------
p = f"{D}/32-upf-pod.yaml"
s = open(p, encoding="utf-8").read()

old_affinity = """spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: kubernetes.io/hostname
                operator: NotIn
                values:
                  - ip-192-168-10-12
"""
new_affinity = """spec:
  nodeSelector:
    kubernetes.io/hostname: ip-192-168-10-11 # kpt-set: ${upf-node}
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: kubernetes.io/hostname
                operator: In
                values:
                  - ip-192-168-10-11 # kpt-set: ${upf-node}
"""
assert old_affinity in s, "UPF affinity marker not found"
s = s.replace(old_affinity, new_affinity, 1)

open(p, "w", encoding="utf-8").write(s)
print("UPF patched")
