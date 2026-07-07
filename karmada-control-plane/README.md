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
