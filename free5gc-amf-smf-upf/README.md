# free5gc-amf-smf-upf kpt Package

> **Đổi quan trọng:** package này giờ **chỉ còn AMF**. SMF và UPF đã được
> tách hẳn ra khỏi Nephio, chuyển sang [`../manual-smf-upf/`](../manual-smf-upf/)
> — 2 thành phần này đang trong giai đoạn thay đổi/thử nghiệm nhiều (SMF dùng
> image SDN-patch riêng, UPF là custom NextMN đang debug), đưa qua vòng
> GitOps đầy đủ (blueprint → Porch upgrade → publish → ArgoCD sync) tạo quá
> nhiều ma sát cho việc lặp nhanh. Tên package **giữ nguyên**
> `free5gc-amf-smf-upf` để không phải xoá/tạo lại deployment đang có trên
> Nephio (đã đổi tên nhiều lần gây phiền — xem lịch sử troubleshooting).

| Thành phần | Namespace | Interface |
|-----------|-----------|-----------|
| AMF | `5gcore` | SBI :80 + NGAP SCTP :38412 (NodePort) |

## Nguồn gốc

Export từ namespace `5gcore` đang chạy thật trên server 5g-control-plane.

## Deploy

```bash
cd free5gc-amf-smf-upf
vi setters.yaml            # chỉnh image/namespace nếu cần
kpt fn render .
kpt live init .
kpt live apply .
```

Yêu cầu package `free5gc-5gcore-others` (đặc biệt NRF) đã deploy xong trước,
vì AMF có initContainer `wait-nrf`.

## SMF / UPF nằm ở đâu?

Xem [`../manual-smf-upf/README.md`](../manual-smf-upf/README.md) — không
qua Nephio, deploy/sửa bằng `kubectl apply` trực tiếp.
