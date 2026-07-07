# upf-migration-nephio

kpt/Nephio package catalog cho hệ thống UPF live-migration 5G (free5GC +
checkpoint/restore + cross-cluster/cross-cloud migrate qua Karmada), export
từ cluster thật đang chạy trên server `5g-control-plane`. Cấu trúc dựa theo
mẫu [`bactp/workload-catalog`](https://github.com/bactp/workload-catalog).

## Package

| Package | Nội dung |
|---|---|
| [`free5gc-5gcore-others`](free5gc-5gcore-others/) | free5GC NF trừ AMF/SMF/UPF: NRF, UDR, UDM, AUSF, PCF, NSSF, CHF, NEF, DBPython, MongoDB, WebUI |
| [`free5gc-amf-smf-upf`](free5gc-amf-smf-upf/) | AMF, SMF, UPF (custom NextMN) + NAD/ConfigMap của UPF |
| [`5g-controllers`](5g-controllers/) | `agent` (checkpoint/restore DaemonSet), `migrate-controller` (Checkpoint/Restore CRD), `enipool-manager` + CR `CloudNICPool` |
| [`upf-migrate-manager`](upf-migrate-manager/) | Controller chính `upf-migrate-controller-manager` (Migrate/Registration/NextmnUPFMap, gRPC `:7000`) |
| [`karmada-control-plane`](karmada-control-plane/) | Shape Karmada hosted-mode (etcd, apiserver, controller-manager, scheduler, webhook) — **không** bundle Secret cert, xem README riêng |

## Thứ tự deploy khuyến nghị

1. **Cilium (CNI) + Multus** — cài trước, ngoài phạm vi package này (Helm/addon riêng), mọi NAD/LoadBalancer trong các package dưới đây phụ thuộc 2 cái này.
2. `karmada-control-plane` (nếu cần cross-cluster migrate — cần Secret cert tồn tại sẵn, xem README)
3. `free5gc-5gcore-others` (PV → namespace/PVC → NRF/MongoDB/...)
4. `free5gc-amf-smf-upf` (phụ thuộc NRF ở bước 3)
5. `5g-controllers` + `upf-migrate-manager` (độc lập, deploy trước/sau/song song đều được)

Mỗi package tự chứa `Kptfile` + `setters.yaml` + `README.md` riêng, xem chi tiết trong từng thư mục.

## `scripts/`

Script dùng để build lại các package này từ export cluster live (không phải
một phần của package, chỉ để tham khảo/tái tạo khi cần).
