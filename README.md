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

## Karmada — cố tình KHÔNG đóng gói

Từng có package `karmada-control-plane` (shape Deployment/StatefulSet/Service
export từ cluster live), nhưng đã **xoá bỏ hoàn toàn**: Karmada hosted-mode
cài qua `karmadactl init`, tự sinh PKI (CA + cert liên kết nhau) lúc cài —
copy shape YAML sang cluster khác vô nghĩa vì không có cert đi kèm, không
portable. Quyết định: **tự chạy `karmadactl init` trực tiếp** trên cluster
cần Karmada, không quản lý qua package Nephio.

## Thứ tự deploy khuyến nghị

1. **Cilium (CNI) + Multus** — cài trước, ngoài phạm vi package này (Helm/addon riêng), mọi NAD/LoadBalancer trong các package dưới đây phụ thuộc 2 cái này.
2. `free5gc-5gcore-others` (namespace → PVC dynamic-provision → NRF/MongoDB/...)
3. `free5gc-amf-smf-upf` (phụ thuộc NRF ở bước 2)
4. `5g-controllers` + `upf-migrate-manager` (độc lập, deploy trước/sau/song song đều được)
5. Nếu cần cross-cluster/cross-cloud migrate: tự `karmadactl init` (xem ghi chú Karmada ở trên) trước khi `upf-migrate-manager` dùng được tính năng multi-cluster — xem README package đó về `karmada-kubeconfig-configmap`.

Mỗi package tự chứa `Kptfile` + `setters.yaml` + `README.md` riêng, xem chi tiết trong từng thư mục.

## `scripts/`

Script dùng để build lại các package này từ export cluster live (không phải
một phần của package, chỉ để tham khảo/tái tạo khi cần).
