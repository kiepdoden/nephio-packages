# upf-migration-nephio

kpt/Nephio blueprint catalog for a 5G UPF live-migration system (free5GC +
checkpoint/restore + cross-cluster / cross-cloud migration via Karmada),
exported from a running production-like cluster. Repository layout follows
the [`bactp/workload-catalog`](https://github.com/bactp/workload-catalog)
pattern.

Porch discovers blueprints in this repo through **git tags** of the form
`<package-dir>/vX.Y.Z` (not by scanning branch content). To publish a new
package revision: edit the package, commit, create the next tag, push both.

## Packages (managed through Nephio)

| Package | Contents |
|---|---|
| [`free5gc-5gcore-others`](free5gc-5gcore-others/) | All free5GC NFs except AMF/SMF/UPF: NRF, UDR, UDM, AUSF, PCF, NSSF, CHF, NEF, DBPython, MongoDB, WebUI |
| [`free5gc-amf-smf-upf`](free5gc-amf-smf-upf/) | AMF (complete) + the ConfigMap/Service/NetworkAttachmentDefinition of SMF and UPF (the SMF Deployment and UPF Pod are intentionally kept outside, see below) |
| [`5g-controllers`](5g-controllers/) | `agent` (checkpoint/restore DaemonSet), `migrate-controller` (Checkpoint/Restore CRDs), `enipool-manager` + `CloudNICPool`/`CloudNICClaim` CRDs (sample CRs kept outside, see below) |
| [`upf-migrate-manager`](upf-migrate-manager/) | The main `upf-migrate-controller-manager` operator (Migrate/Registration/NextmnUPFMap CRDs, gRPC session-delivery server on `:7000`) |

Every package is self-contained: its own `Kptfile` (with an `apply-setters`
mutator), `setters.yaml`, and `README.md`. All environment-specific values
are exposed as setters — fill them per target cluster when you create a
deployment revision (Nephio UI or `kpt fn render`).

## Setters per package

Legend: **must review per environment** = value is tied to the target
cluster/VPC and deploying with the default will break if your environment
differs. *usually keep default* = only change on a new image release or a
deliberate re-design.

### `free5gc-5gcore-others`

| Setter | Default | What to fill |
|---|---|---|
| `namespace` | `5gcore` | Namespace shared by all NFs in this package. *usually keep default* |
| `storage-class` | `longhorn` | **must review per environment.** StorageClass used to dynamically provision `cert-pvc` (mounted `ReadWriteMany` by every NF). The class must exist on the target cluster and support RWX volumes (Longhorn does; EBS does not). MongoDB uses the cluster default StorageClass and is intentionally not setter-ized. |
| `image-mongodb` | `docker.io/bitnami/mongodb:latest` | *usually keep default* |
| `image-nrf` … `image-webui` (`nrf`, `udr`, `udm`, `ausf`, `pcf`, `nssf`, `chf`, `nef`, `dbpython`, `webui`) | `free5gc/<nf>:v4.0.1` (dbpython: `towards5gs/free5gc-dbpython:latest`) | Container image per NF. Bump on release. *usually keep default* |

### `free5gc-amf-smf-upf`

| Setter | Default | What to fill |
|---|---|---|
| `namespace` | `5gcore` | Namespace of the AMF Deployment/Service/ConfigMap and the SMF ConfigMap/Service/NAD. Must match `namespace` of `free5gc-5gcore-others`. *usually keep default* |
| `upf-namespace` | `default` | Namespace of the UPF ConfigMap and n3/n4/n6 NADs. The UPF pod runs in `default` by design (matches the live system). *usually keep default* |
| `image-amf` | `free5gc/amf:v4.0.0` | AMF image. Bump on release. *usually keep default* |

Note: there are deliberately **no** image/node setters for SMF/UPF here —
their Deployment/Pod live in `manual-smf-upf/` (see below).

### `5g-controllers`

| Setter | Default | What to fill |
|---|---|---|
| `agent-namespace` | `agent-system` | Namespace of the checkpoint/restore agent DaemonSet. *usually keep default* |
| `migrate-namespace` | `migrate-system` | Namespace of the Checkpoint/Restore controller. *usually keep default* |
| `enipool-namespace` | `enipool-system` | Namespace of the ENI pool manager. *usually keep default* |
| `image-agent` | `kiemtcb/controller-migrate:agent` | *usually keep default* |
| `image-migrate-controller` | `kiemtcb/controller-migrate:checkpoint-restore-v1` | *usually keep default* |
| `image-enipool-manager` | `kiepdoden123/upf-manager:hybrid-host-device-v3` | The enipool-manager binary ships in the same image as upf-migrate-manager; keep both packages on the **same tag** when releasing fixes that touch `internal/cloud` or `internal/enipool`. |
| `aws-region` | `us-east-2` | **must review per environment.** AWS region of the VPC where pool ENIs are created/attached. |
| `azure-subscription-id` | (sample id) | **must review per environment** (only if Azure migration is used). |
| `azure-resource-group` | `rg-upf-migrate-azure` | **must review per environment** (Azure only). |
| `azure-location` | `eastus2` | **must review per environment** (Azure only). |

Note: the actual `CloudNICPool` CRs are **not** in this package — they carry
raw subnet/SG/subscription IDs and live in `manual-cloudnicpools/` (below).

### `upf-migrate-manager`

| Setter | Default | What to fill |
|---|---|---|
| `namespace` | `upf-migrate-system` | *usually keep default* |
| `image-manager` | `kiepdoden123/upf-manager:hybrid-host-device-v3` | Manager image. Bump on release (see note above about keeping it in sync with `image-enipool-manager`). |
| `aws-region` | `us-east-2` | **must review per environment.** |
| `nrf-address` | `192.168.10.10:30348` | **must review per environment.** `host:port` of the free5GC NRF NodePort **on the cluster where this manager runs** (node IP + NodePort of the NRF service from `free5gc-5gcore-others`). |
| `5gcore-namespace` | `5gcore` | Namespace where the 5G core NFs run; must match `namespace` of the free5gc packages. *usually keep default* |
| `sdn-controller-address` | `192.168.1.10:8000` | **must review per environment.** `host:port` of the SDN Flask server running on the UE/gNB VM (the one that rewrites GTP-U flows in OVS after a migration). Must be reachable from this manager pod. |
| `grpc-host` | `192.168.10.10:7000` | **must review per environment.** Address that UPF pods (including pods on Karmada member clusters) use to call back into this manager's gRPC session-delivery server. Use a node IP (or LB IP) reachable from every member cluster + port `7000`. |

The manager also needs a `karmada-kubeconfig-configmap` in its namespace for
multi-cluster features — see the package README. Two operational gotchas
learned the hard way: (1) the ConfigMap is mounted with `subPath`, so after
updating it you must restart the manager deployment; (2) rebuild it from the
live `karmada-cert` secret whenever the Karmada control plane is recreated
(its PKI regenerates because Karmada etcd uses non-persistent hostPath
storage).

## `manual-smf-upf/` — SMF Deployment + UPF Pod, NOT managed by Nephio

Only the two most frequently changed objects (the SMF Deployment — patched
SDN image — and the UPF Pod — custom NextMN build under active development)
are kept in [`manual-smf-upf/`](manual-smf-upf/): no `Kptfile`, no setters,
no git tag, therefore invisible to Porch. Their supporting
ConfigMap/Service/NADs **stay inside** `free5gc-amf-smf-upf` (stable, rarely
change). Deploy and edit these two with plain `kubectl apply`. Remember to
fix `nodeName`/affinity to real node names of the target cluster before
applying.

## `manual-cloudnicpools/` — sample CloudNICPool CRs, NOT managed by Nephio

Six `CloudNICPool` CRs (3 AWS + 3 Azure), split out of `5g-controllers`
because each CR hard-codes subnet IDs / Security Group IDs (AWS) or
subscription/resource-group (Azure) of **one specific VPC/tenant** —
deploying them into another environment fails immediately. Use the files in
[`manual-cloudnicpools/`](manual-cloudnicpools/) as templates: fill in your
real infrastructure IDs, then `kubectl apply` by hand. Pool naming must
follow `<karmada-member-cluster-name>-<n3|n4|n6>` so the migrate controller
can locate the pools for a given target cluster.

## Karmada — intentionally NOT packaged

A `karmada-control-plane` package existed once (Deployment/StatefulSet/
Service shapes exported from the live cluster) and was **removed on
purpose**: hosted-mode Karmada is installed by `karmadactl init`, which
generates an interlinked PKI (CA + certificates) at install time. Copying
the YAML shapes to another cluster is meaningless without those secrets and
is not portable. Decision: run `karmadactl init` directly on any cluster
that needs Karmada; do not manage it as a Nephio package.

## Prerequisites

The target clusters themselves (`core` and the `edge*` workload clusters)
are **provisioned from the Nephio management cluster** (Cluster API + Porch
PackageVariants + per-cluster ArgoCD bootstrap) before anything in this repo
is deployed. Follow the bootstrap guide here:

- [nephio-test-infra-aws — bootstrap_5g_guide.md](https://github.com/vitu-mafeni/nephio-test-infra-aws/blob/company-version/bootstrap_5g_guide.md)

Once the workload clusters are up and registered (deployment repos created,
ArgoCD syncing), register this repository as an External Blueprints repo in
Nephio and proceed with the order below.

## Recommended deployment order

1. **CNI (Cilium/Flannel) + Multus** — install first, outside this repo
   (Helm/addon); every NAD and LoadBalancer below depends on them.
2. `free5gc-5gcore-others` (namespace → dynamic PVC → NRF/MongoDB/…)
3. `free5gc-amf-smf-upf` (AMF depends on NRF from step 2)
4. `manual-smf-upf/` (`kubectl apply` by hand — requires step 3 first: the
   SMF Deployment / UPF Pod mount ConfigMaps/NADs from that package)
5. `5g-controllers` + `upf-migrate-manager` (independent of free5gc; any
   order, before/after/parallel)
6. `manual-cloudnicpools/` (`kubectl apply` by hand, only needed for
   cross-cluster / cross-cloud migration — fill real subnet/SG/subscription
   first). Requires `5g-controllers` (the `CloudNICPool` CRD) from step 5.
7. For cross-cluster / cross-cloud migration: run `karmadactl init` yourself
   (see the Karmada note above) and create `karmada-kubeconfig-configmap`
   before the multi-cluster features of `upf-migrate-manager` become usable.

## `scripts/`

Helper scripts used to (re)build these packages from a live-cluster export
(dump cleaning, setter tagging, Kptfile generation, dry-run validation).
They are not part of any package — reference only.
