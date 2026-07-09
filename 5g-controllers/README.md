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

> **Đổi quan trọng:** package này **không còn bundle CR `CloudNICPool` cụ
> thể nào nữa** (trước đây có 6 CR mẫu ở `03-cloudnicpools.yaml`, đã bỏ).
> Lý do: mỗi `CloudNICPool` gắn chết với subnet ID/Security Group ID (AWS)
> hoặc subscription/resource-group (Azure) của **1 VPC/tenant cụ thể** —
> đây là data theo môi trường, không phải phần mềm, deploy sang VPC khác là
> sai ngay (subnet/SG không tồn tại). Xem
> [`../manual-cloudnicpools/`](../manual-cloudnicpools/) — CR mẫu để tham
> khảo, tự điền đúng ID hạ tầng thật của cluster đích rồi `kubectl apply`
> tay, không qua Nephio.

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
`upf-migrate-controller-manager` tạo `CloudNICClaim` tham chiếu tới
`CloudNICPool` (giờ tạo tay qua `manual-cloudnicpools/`, xem trên).

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
  `AWS_REGION`/`AZURE_SUBSCRIPTION_ID`/`AZURE_RESOURCE_GROUP`/`AZURE_LOCATION`
  trong `setters.yaml` là credential/context cho chính `enipool-manager`
  chạy — **khác** với data của từng `CloudNICPool` (đã tách ra ngoài), nên
  vẫn giữ lại đây vì đúng chuẩn setter (deployer override trước khi publish).
- `agent` cần chạy trên **mọi node** có khả năng host UPF (DaemonSet,
  `privileged: true`), vì nó thao tác trực tiếp `/var/lib/kubelet/checkpoints/`.
