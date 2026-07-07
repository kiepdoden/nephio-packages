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

Package cũng bundle:
- 6 CRD của group `upf.ahihi.ahuhu/v1` (`Migrate`, `Registration`,
  `NextmnUPFMap`, `CloudNICPool`, `CloudNICClaim`, `IPPool`) — dùng bởi cả
  `enipool-manager` (ở đây) lẫn `upf-migrate-controller-manager` (package
  `upf-migrate-manager`, xem ghi chú bên dưới).
- 2 CRD của group `migrate.ahihi.ahuhu/v1` (`Checkpoint`, `Restore`, đã
  nhúng sẵn trong `20-migrate-controller.yaml`).
- **`03-cloudnicpools.yaml`** — 6 `CloudNICPool` CR đang chạy thật trên cluster
  (`cluster1-n3/n4/n6` cho AWS, `azure-n3/n4/n6` cho Azure), export từ
  `kubectl get cloudnicpools -o yaml` (đã bỏ `status`/runtime metadata —
  `status.available` là danh sách NIC warm-pool, `enipool-manager` tự refill
  lại khi các CR này được apply).

## Deploy

```bash
cd 5g-controllers
vi setters.yaml
kpt fn render .
kpt live init .
kpt live apply .
```

Không phụ thuộc 2 package free5gc — có thể deploy độc lập trước/sau/song song.
Nên deploy **cùng lúc hoặc trước** package `upf-migrate-manager`, vì
`upf-migrate-controller-manager` tạo `CloudNICClaim` tham chiếu tới các
`CloudNICPool` ở đây.

## Ghi chú quan trọng

- Cluster thật có **thêm** một Deployment `upf-migrate-controller-manager`
  (namespace `upf-migrate-system`, gRPC `:7000` LoadBalancer) — controller
  chính xử lý CRD `Migrate`/`Registration`/`NextmnUPFMap`. Component này giờ
  đã được đóng gói riêng ở package **`upf-migrate-manager`** (sourced lại từ
  `/home/ubuntu/upf-migrate/config/manager` + `config/rbac`), **không** nằm
  trong package này — 2 package cùng dùng chung bộ CRD `upf.ahihi.ahuhu/v1`
  ở đây.
- Image `enipool-manager` đã được cập nhật sang tag đang chạy thật trên
  cluster (`hybrid-host-device-v1`) thay vì tag trong
  `config/enipool-manager/deployment.yaml` gốc (`dynamic-nad-v1`, đã cũ).
- `agent` cần chạy trên **mọi node** có khả năng host UPF (DaemonSet,
  `privileged: true`), vì nó thao tác trực tiếp `/var/lib/kubelet/checkpoints/`.
