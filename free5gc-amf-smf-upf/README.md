# free5gc-amf-smf-upf kpt Package

AMF + SMF + UPF (custom NextMN UPF dùng cho PFCP/GTP-U migration testbed)
cùng các NetworkAttachmentDefinition (Multus) và ConfigMap phụ trợ của chúng.

| Thành phần | Namespace | Interface | Ghim node |
|-----------|-----------|-----------|-----------|
| AMF | `5gcore` | SBI :80 + NGAP SCTP :38412 (NodePort) | không setter hoá (chưa yêu cầu) |
| SMF | `5gcore` | SBI :80 + N4/PFCP UDP :8805 (Multus macvlan/ipvlan `ens6`, NAD `n4network-free5gc-free5gc-smf`) | ghim cứng vào node — setter `smf-node` |
| UPF | `default` | N3/N4/N6 qua 3 Multus NAD riêng (`n3-conf`, `n4-conf`, `n6-conf`, ipvlan trên `ens6`/`ens7`/`ens8`) + gRPC session-manager kết nối tới migrate-controller | **tránh** đúng node SMF đang chạy (không ghim node riêng) |

**Lưu ý:** UPF namespace khác với AMF/SMF (`default` vs `5gcore`), khớp đúng
với cách hạ tầng thật đang chạy trên server 5g-control-plane — package này
**không** gộp UPF vào `5gcore`, giữ nguyên đúng namespace live. Setter riêng:
`upf-namespace` (mặc định `default`), tách biệt với `namespace` (AMF/SMF,
mặc định `5gcore`).

## Logic ghim node: SMF cố định, UPF "né" SMF

- **SMF**: `nodeSelector` + `affinity.nodeAffinity` (`operator: In`) — ghim cứng
  vào đúng 1 node, giá trị lấy từ setter `smf-node` (mặc định `ip-192-168-10-12`,
  khớp vị trí đang chạy live).
- **UPF**: chỉ có `affinity.nodeAffinity` (`operator: NotIn`), **dùng chung giá
  trị `smf-node`** — nghĩa là UPF chỉ cần tránh đúng node mà SMF đang ghim, chứ
  không ghim cứng vào 1 node cụ thể nào của riêng nó. Đổi `smf-node` sang node
  khác thì UPF tự động né theo, không cần sửa thêm gì cho UPF.
- Không dùng `nodeSelector` cho UPF (chỉ SMF mới cần ghim cứng tuyệt đối; UPF chỉ
  cần "không đụng SMF" nên nodeAffinity `NotIn` là đủ, để lại chỗ cho scheduler
  tự chọn trong các node còn lại).

## Nguồn gốc

- AMF/SMF: export từ namespace `5gcore` đang chạy thật trên server
  5g-control-plane.
- UPF (`30-*` đến `35-*`): export trực tiếp từ Pod `upf-test-pod` (namespace
  `default` trên cluster thật).

## Deploy

```bash
cd free5gc-amf-smf-upf
vi setters.yaml            # chỉnh image/namespace/upf-namespace/smf-node nếu cần
kpt fn render .
kpt live init .
kpt live apply .
```

Yêu cầu package `free5gc-5gcore-others` (đặc biệt NRF, MongoDB, cert-pvc) đã
deploy xong trước, vì AMF/SMF chờ NRF sẵn sàng (initContainer `wait-nrf`).

**Chưa từng `kpt live apply` package này lên cluster thật** — mọi resource
UPF/AMF/SMF ở đây chỉ là snapshot đã đóng gói lại, không tự động ghi đè hay
tạo mới gì trên cluster đang chạy trừ khi bạn chủ động chạy `kpt live apply`.

## Lưu ý mạng

- UPF cần 3 NIC vật lý/ipvlan-capable trên node (`ens6`, `ens7`, `ens8`) cho
  N3/N4/N6 — subnet mặc định 192.168.40.0/24, 192.168.50.0/24, 192.168.60.0/24.
  Sửa trực tiếp trong `33/34/35-upf-*-nad.yaml` nếu hạ tầng khác.
- `pfcp.addr`/`gtpu` trong `30-upf-configmap.yaml` và `controllerK8s.ip` trong
  `31-upf-session-manager-configmap.yaml` phải khớp IP thật của interface N3/N4
  và IP LoadBalancer của `upf-migrate-controller-manager` (namespace
  `upf-migrate-system` trên cluster thật, hiện là `192.168.10.10:7000` —
  controller này **không nằm trong** package `5g-controllers`, xem README của
  package đó).
- Đổi `smf-node` thì nhớ **cả 2 node liên quan** (node SMF ghim tới, và các
  node còn lại UPF được phép chạy) phải có sẵn đúng NIC vật lý
  (`ens6`/`ens7`/`ens8`) cho NAD tương ứng — nếu không Pod sẽ kẹt
  `ContainerCreating`.
