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
