# manual-cloudnicpools — CloudNICPool CR mẫu, KHÔNG quản lý qua Nephio

Đây **không phải** kpt package (không `Kptfile`, không setter, Porch không
phát hiện). Chứa 6 `CloudNICPool` CR — **dữ liệu tham khảo từ cluster gốc
`5g-control-plane`**, không phải config tổng quát dùng được ở mọi nơi.

## Vì sao tách khỏi package `5g-controllers`

Mỗi `CloudNICPool` gắn chết với hạ tầng cloud **cụ thể** của 1 tài khoản/VPC:

```yaml
subnet: subnet-003529ac1f69c118f          # AWS subnet ID — chỉ tồn tại trong VPC gốc
securityGroups: [sg-0774cb54f05a1f854]    # AWS Security Group ID — chỉ tồn tại trong VPC gốc
subscriptionID: 91414a5d-...              # Azure subscription — chỉ tồn tại trong tenant gốc
resourceGroup: rg-upf-migrate-azure       # Azure resource group — chỉ tồn tại trong subscription gốc
```

Deploy sang cluster/VPC/subscription khác (như cluster `core` hiện tại,
nằm ở VPC `nephio-5g` hoàn toàn khác), các ID này **không tồn tại** —
`enipool-manager` sẽ cố quản lý NIC ở subnet/SG không có thật, gây lỗi
hoặc tệ hơn là âm thầm sai. Đây là **data theo môi trường**, không phải
phần mềm/controller nên không hợp lý để đóng cứng vào blueprint tái sử
dụng được — khác với biến số qua `setters.yaml` (deployer override được
trước khi publish), 6 CR này *là* toàn bộ định nghĩa NIC pool, không có gì
để "setter hoá" từng phần một cách hợp lý.

## Cách dùng

1. Copy 1 CR mẫu (AWS hoặc Azure tuỳ cloud provider của bạn) làm khung.
2. Điền đúng `subnet`/`securityGroups` (AWS) hoặc
   `subscriptionID`/`resourceGroup`/`subnet` (Azure) của **VPC/tenant thật**
   nơi cluster đích đang chạy.
3. Đổi `metadata.name` theo đúng convention `<targetCluster>-<iface>` (vd.
   `core-n3`, `core-n4`, `core-n6` nếu cluster đích tên `core` trong Karmada).
4. `kubectl apply -f aws-cloudnicpools.yaml` (AWS) hoặc `kubectl apply -f azure-cloudnicpools.yaml` (Azure) sau khi package `5g-controllers`
   (chứa `enipool-manager` + CRD `CloudNICPool`) đã deploy xong.

## Nội dung (tham khảo, KHÔNG apply thẳng — điền đúng ID hạ tầng thật trước)

- `cluster1-n3/n4/n6` — mẫu AWS, pool cho member cluster Karmada tên `cluster1`
- `azure-n3/n4/n6` — mẫu Azure, pool cho member cluster Karmada tên `azure`
