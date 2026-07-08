# manual-smf-upf — SMF + UPF, KHÔNG quản lý qua Nephio

Đây **không phải** kpt package (không có `Kptfile`, không có setter, không
được Porch/ArgoCD phát hiện hay đồng bộ). Chỉ là thư mục chứa manifest tĩnh
cho SMF + UPF (custom NextMN-based UPF) — tách khỏi Nephio có chủ đích vì 2
thành phần này đang thay đổi/thử nghiệm liên tục (image SDN-patch riêng cho
SMF, UPF đang debug flow migrate), đi qua GitOps đầy đủ (blueprint → Porch
upgrade → publish → chờ ArgoCD sync) chậm và vướng khi cần lặp nhanh.

## Nội dung

| File | Resource |
|---|---|
| `20-smf.yaml` | ConfigMap + Service + Deployment SMF (namespace `5gcore`) |
| `30-upf-configmap.yaml` | ConfigMap cấu hình PFCP/GTP-U cho UPF |
| `31-upf-session-manager-configmap.yaml` | ConfigMap trỏ tới `upf-migrate-controller-manager` (gRPC) |
| `32-upf-pod.yaml` | Pod UPF (namespace `default`) |
| `33/34/35-upf-n3/n4/n6-nad.yaml` | NetworkAttachmentDefinition Multus cho UPF |

Không còn `# kpt-set:` — mọi giá trị (namespace, image, node...) là **giá
trị tĩnh**, sửa trực tiếp trong file khi cần.

## Deploy / cập nhật

```bash
kubectl apply -f 20-smf.yaml
kubectl apply -f 30-upf-configmap.yaml -f 31-upf-session-manager-configmap.yaml
kubectl apply -f 33-upf-n3-nad.yaml -f 34-upf-n4-nad.yaml -f 35-upf-n6-nad.yaml
kubectl apply -f 32-upf-pod.yaml
```

Yêu cầu package Nephio `free5gc-5gcore-others` (NRF) và `free5gc-amf-smf-upf`
(AMF) đã deploy trước — SMF chờ NRF sẵn sàng (initContainer `wait-nrf`).

## Khi nào đưa lại vào Nephio?

Khi SMF/UPF ổn định, không còn sửa thường xuyên nữa — copy nội dung file ở
đây trở lại `../free5gc-amf-smf-upf/resources/`, thêm lại `# kpt-set:` cho
các giá trị cần setter hoá (namespace, image, node pinning — xem git history
của `free5gc-amf-smf-upf` để lấy lại đúng convention cũ), rồi tag version
mới cho package đó.
