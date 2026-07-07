#!/bin/bash
set -euo pipefail
OUT=/home/ubuntu/nephio-packages

# ============ Package 4: upf-migrate-manager ============
D="$OUT/upf-migrate-manager"
cat > "$D/Kptfile" <<'EOF'
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: upf-migrate-manager
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: Main upf-migrate operator (Migrate/Registration/NextmnUPFMap CRDs, gRPC session-delivery server on :7000)
pipeline:
  mutators:
    - image: ghcr.io/kptdev/krm-functions-catalog/apply-setters:v0.2
      configPath: setters.yaml
EOF

cat > "$D/package-context.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: kptfile.kpt.dev
  annotations:
    config.kubernetes.io/local-config: "true"
data:
  name: upf-migrate-manager
  package-path: upf-migrate-manager
EOF

cat > "$D/setters.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: setters
  annotations:
    config.kubernetes.io/local-config: "true"
data:
  namespace: upf-migrate-system
  image-manager: kiepdoden123/upf-manager:hybrid-host-device-v2
  aws-region: us-east-2
  nrf-address: "192.168.10.10:30348"
  5gcore-namespace: "5gcore"
  sdn-controller-address: "192.168.1.10:8000"
  # Host:port UPF pod dùng để gọi gRPC ngược lại manager (LoadBalancer IP:7000 của Service trong package này)
  grpc-host: "192.168.10.10:7000"
EOF

cat > "$D/README.md" <<'EOF'
# upf-migrate-manager kpt Package

Operator **chính** của repo `gitlab.com/migrate-stateful-upf/upf-migrate`
(`cmd/main.go`, binary "manager") — khác với 2 operator phụ trong package
`5g-controllers` (agent, migrate-controller/Checkpoint-Restore CRD,
enipool-manager). Đây là component còn thiếu mà bước audit trước phát hiện.

| | |
|---|---|
| Namespace | `upf-migrate-system` |
| CRD quản lý | `Migrate`, `Registration`, `NextmnUPFMap`, `CloudNICPool`, `CloudNICClaim`, `IPPool` (`upf.ahihi.ahuhu/v1`) + `Checkpoint`, `Restore` (`migrate.ahihi.ahuhu/v1`) — **CRD đã nằm sẵn trong package `5g-controllers`**, package này chỉ chứa Deployment/RBAC/Service |
| gRPC | Port `:7000`, expose qua `Service` LoadBalancer `upf-migrate-controller-manager-service` — UPF pod (package `free5gc-amf-smf-upf`) gọi vào đây để giao session PFCP khi migrate |
| Cross-cluster | Cần `--enable-multi-cluster=true` (đã bật) + Karmada kubeconfig mount tại `/etc/multi-cluster-config` |

## Nguồn gốc

Dựng lại từ `/home/ubuntu/upf-migrate/config/manager/manager.yaml` +
`config/rbac/*.yaml` (kustomize base gốc, namespace `system` + namePrefix
`upf-migrate-` → tên thật `upf-migrate-*`), khớp với những gì đang chạy live
trong namespace `upf-migrate-system` (đã đối chiếu qua `kubectl get deploy/svc`).

## Deploy

```bash
cd upf-migrate-manager
vi setters.yaml
kpt fn render .
kpt live init .
kpt live apply .
```

Yêu cầu **trước khi apply**:
1. Package `5g-controllers` đã deploy (cần CRD `Migrate`/`Registration`/
   `NextmnUPFMap`/`CloudNICPool`/`CloudNICClaim`/`IPPool` tồn tại trước).
2. **`ConfigMap karmada-kubeconfig-configmap`** phải tồn tại thủ công trong
   namespace `upf-migrate-system` trước khi Deployment start được — đây là
   kubeconfig do Karmada cấp (package `karmada-control-plane`) để manager
   propagate resource sang member cluster. **Package này cố tình không tạo
   ConfigMap đó** vì nó chứa dữ liệu kết nối/credential runtime, không phải
   config tĩnh nên không hợp lý để checked-in vào Git — tạo thủ công bằng:
   ```bash
   kubectl get secret karmada-kubeconfig -n karmada-system -o jsonpath='{.data.kubeconfig}' \
     | base64 -d > /tmp/karmada.kubeconfig
   kubectl create configmap karmada-kubeconfig-configmap \
     --from-file=kubeconfig=/tmp/karmada.kubeconfig -n upf-migrate-system
   ```
   (tên secret thật tuỳ theo cách bạn khởi tạo Karmada — xem package
   `karmada-control-plane`.)
EOF

echo "pkg4 done"

# ============ Package 5: karmada-control-plane ============
D="$OUT/karmada-control-plane"
cat > "$D/Kptfile" <<'EOF'
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: karmada-control-plane
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: Karmada control plane (hosted-mode, installed via karmadactl init) — enables multi-cluster/cross-cloud propagation used by upf-migrate-manager
pipeline:
  mutators:
    - image: ghcr.io/kptdev/krm-functions-catalog/apply-setters:v0.2
      configPath: setters.yaml
EOF

cat > "$D/package-context.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: kptfile.kpt.dev
  annotations:
    config.kubernetes.io/local-config: "true"
data:
  name: karmada-control-plane
  package-path: karmada-control-plane
EOF

cat > "$D/setters.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: setters
  annotations:
    config.kubernetes.io/local-config: "true"
data:
  namespace: karmada-system
  image-karmada-apiserver: registry.k8s.io/kube-apiserver:v1.35.2
  image-karmada-aggregated-apiserver: docker.io/karmada/karmada-aggregated-apiserver:v1.17.1
  image-karmada-webhook: docker.io/karmada/karmada-webhook:v1.17.1
  image-karmada-controller-manager: docker.io/karmada/karmada-controller-manager:v1.17.1
  image-karmada-scheduler: docker.io/karmada/karmada-scheduler:v1.17.1
  image-kube-controller-manager: registry.k8s.io/kube-controller-manager:v1.35.2
  image-etcd: registry.k8s.io/etcd:3.6.6-0
  # etcd data hiện lưu hostPath trên đúng 1 node (không phải PVC) — xem README
  etcd-hostpath: /var/lib/karmada-etcd
EOF

cat > "$D/README.md" <<'EOF'
# karmada-control-plane kpt Package

Karmada control plane chạy **hosted mode** (các component chạy như Pod
thường ngay trong cluster host, không phải cluster riêng) — nền tảng
multi-cluster propagation mà `upf-migrate-controller-manager` (package
`upf-migrate-manager`) dùng để đẩy Checkpoint/Restore/Pod sang member cluster
khi migrate cross-cluster/cross-cloud.

| Component | Vai trò |
|---|---|
| `etcd` (StatefulSet) | Datastore riêng của Karmada, **tách biệt** etcd của cluster host |
| `karmada-apiserver` | API server riêng cho Karmada resource (`Cluster`, `PropagationPolicy`...), expose NodePort `:32443` |
| `karmada-aggregated-apiserver` | Aggregated API cho search/cluster-proxy |
| `karmada-controller-manager` | Reconcile propagation/binding |
| `karmada-scheduler` | Chọn member cluster cho resource được propagate |
| `karmada-webhook` | Validate/mutate Karmada resource |
| `kube-controller-manager` | Controller manager chuẩn của K8s, chạy cho riêng Karmada API server (vì karmada-apiserver là 1 K8s apiserver độc lập, cần controller-manager riêng cho ServiceAccount/token...) |

## QUAN TRỌNG — giới hạn của package này

Karmada **không** cài đặt bằng cách rải YAML tĩnh — công cụ chính thức
`karmadactl init` sinh toàn bộ PKI (CA + cert cho từng component, liên kết
với nhau) và ghi vào Secret (`karmada-cert`, `etcd-cert`, ...) tại thời điểm
cài. Package này:

- **CÓ**: shape đầy đủ của Deployment/StatefulSet/Service (đúng flag, đúng
  image, đúng version) — dùng để tham khảo/audit cấu hình đang chạy, hoặc
  làm input cho `karmadactl init --karmada-apiserver-image=... ` nếu cần dựng
  lại đúng version.
- **KHÔNG** bundle Secret cert (`karmada-cert`, `etcd-cert`,
  `karmada-webhook-cert`, `*-config`...) — các Secret này chứa private key/CA,
  không hợp lý (và không an toàn) để checked-in Git. Muốn tái tạo control
  plane này ở nơi khác, chạy `karmadactl init` để tự sinh bộ cert mới, PKI mới
  — **không copy Secret từ cluster hiện tại sang**.
- Do đó `kpt live apply` package này **sẽ thất bại** nếu Secret chưa tồn tại
  — chỉ dùng để tái-apply lên **đúng cluster đã có sẵn Secret** (ví dụ sau khi
  lỡ xoá nhầm Deployment nhưng Secret vẫn còn), không phải để bootstrap mới.

## Ghi chú vận hành

- `etcd` StatefulSet dùng `hostPath: /var/lib/karmada-etcd` (setter
  `etcd-hostpath`), **không phải PVC** — dữ liệu Karmada etcd gắn chặt với 1
  node vật lý, không tự chịu được node đó chết. Không có backup/snapshot tự
  động nào được thiết lập.
- Không có `ClusterRole`/`ClusterRoleBinding` nào trên cluster host gắn với
  Karmada — các Pod chạy bằng ServiceAccount `default`, tự chứa toàn bộ logic
  auth qua các cert mount, không cần RBAC K8s host.

## Deploy (chỉ khi Secret cert đã tồn tại)

```bash
cd karmada-control-plane
vi setters.yaml
kpt fn render .
kpt live init .
kpt live apply .
```
EOF

echo "pkg5 done"
