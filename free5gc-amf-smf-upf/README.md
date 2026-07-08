# free5gc-amf-smf-upf kpt Package

> **Đổi quan trọng:** Deployment SMF và Pod UPF (2 object hay thay đổi nhất —
> SMF dùng image SDN-patch riêng, UPF là custom NextMN đang debug flow
> migrate) đã tách ra [`../manual-smf-upf/`](../manual-smf-upf/), **không**
> qua Nephio. Phần **config/network còn lại của SMF và UPF** (ConfigMap,
> Service, NetworkAttachmentDefinition) **vẫn ở lại package này** — những
> thứ đó ổn định, ít đổi, hợp lý để giữ trong GitOps.

| Thành phần | Trong package này | Trong `manual-smf-upf/` |
|---|---|---|
| AMF | ConfigMap + Service + Deployment (đầy đủ) | — |
| SMF | ConfigMap + Service + NAD (`n4network-...`) | **Deployment** (`20-smf-deployment.yaml`) |
| UPF | ConfigMap (`config-upf`) + ConfigMap (`session-manager`) + 3 NAD (n3/n4/n6) | **Pod** (`32-upf-pod.yaml`) |

## Nguồn gốc

Export từ namespace `5gcore`/`default` đang chạy thật trên server
5g-control-plane.

## Deploy

```bash
cd free5gc-amf-smf-upf
vi setters.yaml            # chỉnh namespace/upf-namespace/image-amf nếu cần
kpt fn render .
kpt live init .
kpt live apply .
```

Yêu cầu package `free5gc-5gcore-others` (NRF) đã deploy trước — AMF có
initContainer `wait-nrf`.

Sau khi package này chạy xong (có ConfigMap/Service/NAD sẵn sàng), mới
`kubectl apply` phần Deployment SMF + Pod UPF trong
[`../manual-smf-upf/`](../manual-smf-upf/) — 2 object đó cần ConfigMap/NAD
ở đây tồn tại trước (mount ConfigMap, gán NAD theo tên).
