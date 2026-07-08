# free5gc-5gcore-others kpt Package

Tất cả Network Function của free5GC 5GCore **ngoại trừ AMF, SMF, UPF** (những
NF đó nằm trong package `free5gc-amf-smf-upf`). Package này gồm:

| NF | Vai trò |
|----|---------|
| MongoDB | Subscriber database backend |
| NRF | Network Repository Function |
| UDR | Unified Data Repository |
| UDM | Unified Data Management |
| AUSF | Authentication Server Function |
| PCF | Policy Control Function |
| NSSF | Network Slice Selection Function |
| CHF | Charging Function |
| NEF | Network Exposure Function |
| DBPython | Helper tool thao tác trực tiếp MongoDB (free5GC dbpython) |
| WebUI | free5GC WebConsole |

Namespace mặc định: `5gcore` (dùng chung với package `free5gc-amf-smf-upf`,
vì AMF/SMF cần resolve các NF này qua Service DNS trong cùng namespace).

## Nguồn gốc

Nội dung được export từ cụm Kubernetes đang chạy thật (namespace `5gcore`
trên server 5g-control-plane, xem `kubectl get all -n 5gcore`) và cấu trúc
lại theo chuẩn kpt package (tham khảo `bactp/workload-catalog`).

## Storage — dynamic provisioning (StorageClass), không dùng static PV

> **Đổi so với bản đầu:** package này ban đầu dùng 2 `PersistentVolume` tĩnh
> trỏ thẳng NFS server (`192.168.10.10`) của cluster gốc `5g-control-plane`.
> Khi deploy sang cluster khác không reach được NFS đó, 2 PV này kẹt mãi ở
> trạng thái `Available`, không PVC nào bind được → toàn bộ NF không khởi
> động nổi. Đã đổi lại **đúng theo cách package mẫu `bactp/workload-catalog`
> làm**: dùng dynamic provisioning qua StorageClass, portable — chạy được
> trên bất kỳ cluster nào miễn có StorageClass phù hợp.

- **MongoDB**: `volumeClaimTemplates` trong StatefulSet, **không set
  `storageClassName`** → tự dùng StorageClass mặc định (`default`) của
  cluster đích. Không cần setter riêng.
- **`cert-pvc`** (dùng chung bởi mọi NF để đọc TLS cert): PVC với
  `storageClassName: longhorn # kpt-set: ${storage-class}` — đổi setter
  `storage-class` trong `setters.yaml` nếu cluster đích không có SC tên
  `longhorn`.

> **Lưu ý quan trọng — access mode:** `cert-pvc` dùng
> `accessModes: ReadWriteMany` (**không phải `ReadOnlyMany`**). Đã thử
> `ReadOnlyMany` trước nhưng **Longhorn CSI driver không hề implement access
> mode này** (lỗi thật gặp phải: `access mode MULTI_NODE_READER_ONLY is not
> supported`) — Longhorn chỉ hỗ trợ `ReadWriteOnce` và `ReadWriteMany` (qua
> Share Manager/NFS backend), không có khái niệm "nhiều node, chỉ đọc". Vì
> nhiều NF pod trên nhiều node khác nhau cùng cần đọc cert-pvc, `ReadWriteMany`
> là lựa chọn khả thi duy nhất trên Longhorn (các pod vẫn tự mount
> `readOnly: true` ở cấp volumeMount, PVC RWX chỉ nói "được phép", không bắt
> buộc pod phải ghi).
>
> Nếu `cert-pvc` vẫn `Pending` sau khi đổi accessMode, khả năng cao Longhorn
> Share Manager (thành phần cấp RWX) chưa được bật/cài trên cluster đích —
> kiểm tra `kubectl get pods -n longhorn-system | grep share-manager`. Nếu
> StorageClass đích hoàn toàn không hỗ trợ RWX, phương án dự phòng là bỏ
> `cert-pvc` dùng chung, chuyển sang cert bundled sẵn trong image (kiểu
> `bactp/workload-catalog`) hoặc Secret riêng — cần thiết kế lại, chưa làm
> trong package này.

## Deploy

```bash
cd free5gc-5gcore-others
vi setters.yaml               # chỉnh namespace/image/storage-class nếu cần
kpt fn render .
kpt live init .                # lần đầu
kpt live apply .
```

Không còn bước apply PV riêng trước nữa — mọi thứ trong 1 lần `kpt live
apply .`, thứ tự apply do kubectl/kpt tự lo (Namespace/PVC luôn đi trước
workload nhờ cơ chế sắp xếp mặc định).

Deploy package này **trước** `free5gc-amf-smf-upf`, vì AMF/SMF phụ thuộc NRF.

## Lưu ý

- Cấu hình chi tiết từng NF (PLMN, slice, SUCI key...) nằm trong khối
  `data.<nf>cfg.yaml` của từng ConfigMap — sửa trực tiếp nếu cần thay đổi,
  các giá trị này không được expose qua `setters.yaml` (giữ đúng mức độ mà
  package `bactp/workload-catalog` mẫu áp dụng: chỉ setter hoá namespace/image,
  không setter hoá toàn bộ nested config).
