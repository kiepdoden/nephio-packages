#!/bin/bash
set -euo pipefail
OUT=/home/ubuntu/nephio-packages

# ============ Package 1: free5gc-5gcore-others ============
D="$OUT/free5gc-5gcore-others"
cat > "$D/Kptfile" <<'EOF'
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: free5gc-5gcore-others
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: free5GC 5GCore network functions excluding AMF/SMF/UPF (NRF, UDR, UDM, AUSF, PCF, NSSF, CHF, NEF, DBPython, MongoDB, WebUI)
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
  name: free5gc-5gcore-others
  package-path: free5gc-5gcore-others
EOF

cat > "$D/setters.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: setters
  annotations:
    config.kubernetes.io/local-config: "true"
data:
  # Namespace shared by all NFs in this package
  namespace: 5gcore
  # NFS server backing the shared cert/mongo PersistentVolumes
  nfs-server: 192.168.10.10
  # Container images
  image-mongodb: docker.io/bitnami/mongodb:latest
  image-nrf: free5gc/nrf:v4.0.1
  image-udr: free5gc/udr:v4.0.1
  image-udm: free5gc/udm:v4.0.1
  image-ausf: free5gc/ausf:v4.0.1
  image-pcf: free5gc/pcf:v4.0.1
  image-nssf: free5gc/nssf:v4.0.1
  image-chf: free5gc/chf:v4.0.1
  image-nef: free5gc/nef:v4.0.1
  image-dbpython: towards5gs/free5gc-dbpython:latest
  image-webui: free5gc/webui:v4.0.1
EOF

cat > "$D/README.md" <<'EOF'
# free5gc-5gcore-others kpt Package

Tất cả Network Function của free5GC 5GCore **ngoại trừ AMF, SMF, UPF** (những
NF đó nằm trong package `free5gc-amf-smf-upf`). Package này gồm:

| NF | Vai trò |
|----|---------|
| MongoDB | Subscriber database backend |
| NRF | Network Repository Function |
| UDR | Unified Data Repository |
| UDM | Unified Data Management |
| AUSF | Authentication Server Function |
| PCF | Policy Control Function |
| NSSF | Network Slice Selection Function |
| CHF | Charging Function |
| NEF | Network Exposure Function |
| DBPython | Helper tool thao tác trực tiếp MongoDB (free5GC dbpython) |
| WebUI | free5GC WebConsole |

Namespace mặc định: `5gcore` (dùng chung với package `free5gc-amf-smf-upf`,
vì AMF/SMF cần resolve các NF này qua Service DNS trong cùng namespace).

## Nguồn gốc

Nội dung được export từ cụm Kubernetes đang chạy thật (namespace `5gcore`
trên server 5g-control-plane, xem `kubectl get all -n 5gcore`) và cấu trúc
lại theo chuẩn kpt package (tham khảo `bactp/workload-catalog`).

## Deploy

```bash
cd free5gc-5gcore-others
vi setters.yaml           # chỉnh namespace/image nếu cần
kpt fn render .
kubectl apply -f resources/00-common.yaml   # tạo namespace + cert-pvc trước
kpt live init .            # lần đầu
kpt live apply .
```

Deploy package này **trước** `free5gc-amf-smf-upf`, vì AMF/SMF phụ thuộc NRF.

## Lưu ý

- Cấu hình chi tiết từng NF (PLMN, slice, SUCI key...) nằm trong khối
  `data.<nf>cfg.yaml` của từng ConfigMap — sửa trực tiếp nếu cần thay đổi,
  các giá trị này không được expose qua `setters.yaml` (giữ đúng mức độ mà
  package `bactp/workload-catalog` mẫu áp dụng: chỉ setter hoá namespace/image,
  không setter hoá toàn bộ nested config).
- `cert-pvc` (trong `00-common.yaml`) và các PersistentVolume NFS
  (`01-pv-cert.yaml`, `02-pv-mongo.yaml`) phải tồn tại trước khi các NF khởi
  động, vì mọi NF mount `cert-pvc` để đọc TLS cert.
EOF

echo "pkg1 done"

# ============ Package 2: free5gc-amf-smf-upf ============
D="$OUT/free5gc-amf-smf-upf"
cat > "$D/Kptfile" <<'EOF'
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: free5gc-amf-smf-upf
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: free5GC AMF + SMF + UPF (custom NextMN-based UPF) and their Multus network resources
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
  name: free5gc-amf-smf-upf
  package-path: free5gc-amf-smf-upf
EOF

cat > "$D/setters.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: setters
  annotations:
    config.kubernetes.io/local-config: "true"
data:
  # Namespace shared with package free5gc-5gcore-others
  namespace: 5gcore
  # Container images
  image-amf: free5gc/amf:v4.0.0
  image-smf: kiemtcb/smf:v4.0.0-sdn
  image-upf: docker.io/kiemtcb/upf-test:nextmn-test-not-debug
EOF

cat > "$D/README.md" <<'EOF'
# free5gc-amf-smf-upf kpt Package

AMF + SMF + UPF (custom NextMN UPF dùng cho PFCP/GTP-U migration testbed)
cùng các NetworkAttachmentDefinition (Multus) và ConfigMap phụ trợ của chúng.

| Thành phần | Interface |
|-----------|-----------|
| AMF | SBI :80 + NGAP SCTP :38412 (NodePort) |
| SMF | SBI :80 + N4/PFCP UDP :8805 (Multus macvlan/ipvlan `ens6`, NAD `n4network-free5gc-free5gc-smf`) |
| UPF | N3/N4/N6 qua 3 Multus NAD riêng (`n3-conf`, `n4-conf`, `n6-conf`, ipvlan trên `ens6`/`ens7`/`ens8`) + gRPC session-manager kết nối tới migrate-controller (`upf-migrate-controller-manager`, package `5g-controllers`) |

## Nguồn gốc

- AMF/SMF: export từ namespace `5gcore` đang chạy thật trên server
  5g-control-plane.
- UPF (`30-*` đến `35-*`): export trực tiếp từ Pod `upf-test-pod` (namespace
  `default` trên cluster thật) — package này **chuyển UPF sang namespace
  `5gcore`** để gộp chung với AMF/SMF thành 1 unit triển khai duy nhất
  (khác với cluster hiện tại, nơi UPF đang chạy tạm ở namespace `default`).
  Nếu deploy song song với cluster live cũ, đổi `namespace` setter hoặc rename
  resource để tránh trùng.

## Deploy

```bash
cd free5gc-amf-smf-upf
vi setters.yaml            # chỉnh image/namespace nếu cần
kpt fn render .
kpt live init .
kpt live apply .
```

Yêu cầu package `free5gc-5gcore-others` (đặc biệt NRF, MongoDB, cert-pvc) đã
deploy xong trước, vì AMF/SMF chờ NRF sẵn sàng (initContainer `wait-nrf`).

## Lưu ý mạng

- UPF cần 3 NIC vật lý/ipvlan-capable trên node (`ens6`, `ens7`, `ens8`) cho
  N3/N4/N6 — subnet mặc định 192.168.40.0/24, 192.168.50.0/24, 192.168.60.0/24.
  Sửa trực tiếp trong `33/34/35-upf-*-nad.yaml` nếu hạ tầng khác.
- `pfcp.addr`/`gtpu` trong `30-upf-configmap.yaml` và `controllerK8s.ip` trong
  `31-upf-session-manager-configmap.yaml` phải khớp IP thật của interface N3/N4
  và IP LoadBalancer của `upf-migrate-controller-manager` (package
  `5g-controllers`, hiện là `192.168.10.10:7000`).
EOF

echo "pkg2 done"

# ============ Package 3: 5g-controllers ============
D="$OUT/5g-controllers"
cat > "$D/Kptfile" <<'EOF'
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: 5g-controllers
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: UPF checkpoint/restore agent, migrate-controller and enipool-manager (cross-cluster/cross-cloud UPF live migration operators)
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
  name: 5g-controllers
  package-path: 5g-controllers
EOF

cat > "$D/setters.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: setters
  annotations:
    config.kubernetes.io/local-config: "true"
data:
  # Namespaces (mỗi controller có 1 namespace riêng theo thiết kế gốc)
  agent-namespace: agent-system
  migrate-namespace: migrate-system
  enipool-namespace: enipool-system
  # Container images
  image-agent: kiemtcb/controller-migrate:agent
  image-migrate-controller: kiemtcb/controller-migrate:checkpoint-restore-v1
  image-enipool-manager: kiepdoden123/upf-manager:hybrid-host-device-v1
  # enipool-manager cloud credentials/context
  aws-region: us-east-2
  azure-subscription-id: "91414a5d-9d4e-4b1a-8de6-d0a95a6d0490"
  azure-resource-group: rg-upf-migrate-azure
  azure-location: eastus2
EOF

cat > "$D/README.md" <<'EOF'
# 5g-controllers kpt Package

3 Kubernetes operator hỗ trợ **live migration UPF stateful** trong mạng 5G
(trong-cluster checkpoint/restore, và cross-cluster/cross-cloud AWS↔Azure qua
Karmada). Nguồn gốc: repo `gitlab.com/migrate-stateful-upf/upf-migrate`
(`/home/ubuntu/upf-migrate` trên server 5g-control-plane).

| Thành phần | Namespace | Vai trò |
|-----------|-----------|---------|
| **agent** (`agent-controller-manager`, DaemonSet) | `agent-system` | Chạy trên từng node, quyền `privileged`+`SYS_ADMIN`, mount `/var/lib/kubelet/checkpoints/`; thực thi checkpoint/restore CRIU cho pod UPF (reconcile CRD `Checkpoint`/`Restore` ở cấp node) |
| **migrate-controller** (`migrate-controller-manager`) | `migrate-system` | Định nghĩa & quản lý CRD `Checkpoint`/`Restore` (`migrate.ahihi.ahuhu/v1`) |
| **enipool-manager** | `enipool-system` | Quản lý vòng đời NIC cloud (AWS ENI / Azure NIC) qua CRD `CloudNICPool`/`CloudNICClaim` (`upf.ahihi.ahuhu/v1`), cấp NIC "warm pool" cho migrate sang cluster khác |

Package cũng bundle 6 CRD của group `upf.ahihi.ahuhu/v1` (`Migrate`,
`Registration`, `NextmnUPFMap`, `CloudNICPool`, `CloudNICClaim`, `IPPool` —
dùng bởi manager chính `upf-migrate-controller-manager` chạy trong namespace
`upf-migrate-system`, **không nằm trong package này**, xem ghi chú bên dưới)
và 2 CRD của group `migrate.ahihi.ahuhu/v1` (`Checkpoint`, `Restore`, đã
nhúng sẵn trong `20-migrate-controller.yaml`).

## Deploy

```bash
cd 5g-controllers
vi setters.yaml
kpt fn render .
kpt live init .
kpt live apply .
```

Không phụ thuộc 2 package free5gc — có thể deploy độc lập trước/sau/song song.

## Ghi chú quan trọng

- Cluster thật hiện có **thêm** một Deployment `upf-migrate-controller-manager`
  trong namespace `upf-migrate-system` (image
  `kiepdoden123/upf-manager:hybrid-host-device-v2`, expose gRPC `:7000` qua
  LoadBalancer tại `192.168.10.10`) — đây là controller chính xử lý CRD
  `Migrate`/`Registration`/`NextmnUPFMap` và giao tiếp gRPC với UPF (session
  delivery). Package này **chưa bundle Deployment đó** vì người dùng chỉ yêu
  cầu "agent, upf migrate controller, enipool" dựa trên 3 file gốc
  (`agent-controller.yaml`, `migrate-controller.yaml`, enipool deployment) —
  nếu cần thêm binary `upf-migrate` manager (`cmd/main.go`), lấy từ
  `/home/ubuntu/upf-migrate/config/manager/manager.yaml` +
  `config/rbac/*` và thêm vào package này.
- Image `enipool-manager` đã được cập nhật sang tag đang chạy thật trên
  cluster (`hybrid-host-device-v1`) thay vì tag trong
  `config/enipool-manager/deployment.yaml` gốc (`dynamic-nad-v1`, đã cũ).
- `agent` cần chạy trên **mọi node** có khả năng host UPF (DaemonSet,
  `privileged: true`), vì nó thao tác trực tiếp `/var/lib/kubelet/checkpoints/`.
EOF

echo "pkg3 done"
