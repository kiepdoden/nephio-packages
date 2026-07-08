# manual-smf-upf — Deployment SMF + Pod UPF, KHÔNG quản lý qua Nephio

Đây **không phải** kpt package (không có `Kptfile`, không có setter, không
được Porch/ArgoCD phát hiện hay đồng bộ). Chỉ chứa đúng 2 object hay thay
đổi nhất trong toàn hệ thống — tách khỏi Nephio có chủ đích để sửa/áp lại
nhanh, không phải đi qua GitOps đầy đủ (blueprint push → Porch upgrade →
publish → chờ ArgoCD sync) mỗi lần đổi 1 dòng image tag hay debug logic.

**Config/network hỗ trợ (ConfigMap, Service, NAD) của SMF và UPF vẫn nằm
trong package Nephio [`../free5gc-amf-smf-upf/`](../free5gc-amf-smf-upf/)**
— chỉ tách đúng phần workload (Deployment/Pod) ra đây.

## Nội dung

| File | Resource |
|---|---|
| `20-smf-deployment.yaml` | Deployment SMF (namespace `5gcore`) — mount ConfigMap `free5gc-free5gc-smf-configmap` và NAD `n4network-free5gc-free5gc-smf` từ package Nephio |
| `32-upf-pod.yaml` | Pod UPF (namespace `default`) — mount ConfigMap `config-upf-configmap`/`session-manager-configmap`, gán NAD `n3-conf`/`n4-conf`/`n6-conf` từ package Nephio |

Không có `# kpt-set:` — mọi giá trị (image, node pinning...) là **giá trị
tĩnh**, sửa trực tiếp trong file khi cần rồi `kubectl apply` lại.

## Deploy / cập nhật

```bash
# Yêu cầu package Nephio free5gc-amf-smf-upf đã apply xong (ConfigMap/Service/NAD tồn tại)
kubectl apply -f 20-smf-deployment.yaml
kubectl apply -f 32-upf-pod.yaml
```

## Khi nào đưa lại vào Nephio?

Khi SMF/UPF ổn định, không còn sửa thường xuyên — copy nội dung Deployment/
Pod ở đây trở lại `../free5gc-amf-smf-upf/resources/` (gộp lại thành file
tương ứng), thêm lại `# kpt-set:` cho các giá trị cần setter hoá (image,
node pinning — xem git history của `free5gc-amf-smf-upf` để lấy đúng
convention cũ), rồi tag version mới cho package đó.
