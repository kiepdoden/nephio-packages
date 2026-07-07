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

## Thứ tự resource (quan trọng)

File trong `resources/` được đánh số để **PersistentVolume luôn đứng trước**
mọi thứ khác — khác với repo mẫu `bactp/workload-catalog` (dùng
`volumeClaimTemplates` + StorageClass động cho MongoDB, không cần PV tĩnh).
Ở đây dùng PV tĩnh trỏ thẳng NFS thật (`192.168.10.10`), nên phải tồn tại
**trước khi bất kỳ NF nào kịp chạy**, không phó thác cho apply-order ngầm của
kubectl/kpt:

```
00-pv-cert.yaml    # PersistentVolume free5gc-pv-cert (NFS /var/nfs/general/cert)
01-pv-mongo.yaml   # PersistentVolume free5gc-pv-mongo (NFS /var/nfs/general/mongo)
02-common.yaml     # Namespace 5gcore + PVC cert-pvc (bind vào PV ở trên)
10-mongodb.yaml    # StatefulSet mongodb (PVC riêng, tự bind vào free5gc-pv-mongo)
20-nrf.yaml ...    # các NF còn lại
```

## Deploy

```bash
cd free5gc-5gcore-others
vi setters.yaml               # chỉnh namespace/image/nfs-server nếu cần
kpt fn render .

# 1. PV trước tiên, trước cả namespace — theo đúng thứ tự file
kubectl apply -f resources/00-pv-cert.yaml
kubectl apply -f resources/01-pv-mongo.yaml

# 2. Namespace + PVC — PV đã có sẵn nên bind ngay, không rơi vào Pending
kubectl apply -f resources/02-common.yaml

# 3. Phần còn lại (MongoDB, NRF, UDR, ...)
kpt live init .                # lần đầu
kpt live apply .
```

Deploy package này **trước** `free5gc-amf-smf-upf`, vì AMF/SMF phụ thuộc NRF.

## Lưu ý

- Cấu hình chi tiết từng NF (PLMN, slice, SUCI key...) nằm trong khối
  `data.<nf>cfg.yaml` của từng ConfigMap — sửa trực tiếp nếu cần thay đổi,
  các giá trị này không được expose qua `setters.yaml` (giữ đúng mức độ mà
  package `bactp/workload-catalog` mẫu áp dụng: chỉ setter hoá namespace/image,
  không setter hoá toàn bộ nested config).
- `cert-pvc` (trong `02-common.yaml`) mount vào **mọi** NF để đọc TLS cert —
  phải bind thành công (tức 2 PV ở `00-pv-cert.yaml`/`01-pv-mongo.yaml` phải
  apply trước) trước khi NF nào khởi động, nếu không Pod sẽ kẹt `Pending`.
