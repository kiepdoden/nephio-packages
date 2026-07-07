p = "/home/ubuntu/nephio-packages/free5gc-amf-smf-upf/resources/32-upf-pod.yaml"
s = open(p, encoding="utf-8").read()

old = """spec:
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
new = """spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: kubernetes.io/hostname
                operator: NotIn
                values:
                  - ip-192-168-10-12 # kpt-set: ${smf-node}
"""
assert old in s, "marker not found"
s = s.replace(old, new, 1)
open(p, "w", encoding="utf-8").write(s)
print("UPF affinity reverted to NotIn(smf-node)")
