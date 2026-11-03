# Requirements and dependencies

This repository has no build step. It ships Kubernetes manifests packaged as
kpt/Nephio blueprints, two folders of manifests applied by hand, and helper
scripts. Installation steps and the deployment order are in
[`README.md`](README.md); this file lists what must exist before deploying.

## Deployment tools

| Tool | Used for |
|---|---|
| `kubectl` | Applying `manual-smf-upf/` and `manual-cloudnicpools/`; checking resources |
| `kpt` v1 CLI | `kpt fn render`, `kpt live init`, `kpt live apply` on each package |
| Docker or Podman | Lets `kpt fn render` run the `apply-setters:v0.2` KRM function declared in every `Kptfile` |
| Nephio management cluster (Porch, ArgoCD, Cluster API) | Optional, to consume this repo as an External Blueprints repository and to provision the target clusters (see *Prerequisites* in `README.md`) |

## Target Kubernetes cluster(s)

- A primary CNI (Cilium or Flannel) plus **Multus CNI**: the UPF N3/N4/N6 and
  SMF N4 interfaces are `NetworkAttachmentDefinition`s.
- A StorageClass that supports `ReadWriteMany` for the shared `cert-pvc`
  (default setter value: `longhorn`, with Longhorn Share Manager enabled), and a
  default StorageClass for MongoDB.
- Nodes that can create container checkpoints through the kubelet checkpoint
  API (CRIU-capable container runtime). The `agent` DaemonSet runs privileged
  on every node that may host a UPF and reads `/var/lib/kubelet/checkpoints/`.
- A LoadBalancer implementation (or reachable node IP) for the gRPC
  session-delivery Service of `upf-migrate-manager` on port `7000`.

## Additional requirements for cross-cluster / cross-cloud migration

- Karmada control plane, installed with `karmadactl init`, and the
  `karmada-kubeconfig-configmap` ConfigMap in the `upf-migrate-system`
  namespace (see `upf-migrate-manager/README.md`).
- An AWS VPC and/or Azure VNet where the `enipool-manager` is allowed to
  create and attach network interfaces, and `CloudNICPool` objects filled with
  the real subnet / security-group / subscription values
  (`manual-cloudnicpools/`).
- The SDN controller (HTTP server on the UE/gNB VM that rewrites GTP-U flows in
  Open vSwitch after a migration), reachable at the `sdn-controller-address`
  setter. It is a separate component and is not part of this repository.

## Container images used by the manifests

| Image | Component | Origin |
|---|---|---|
| `kiepdoden123/upf-manager:hybrid-host-device-v3` | `upf-migrate-controller-manager`, `enipool-manager` | Lab (upf-migrate project) |
| `kiemtcb/controller-migrate:agent` | Checkpoint/restore `agent` DaemonSet | Lab |
| `kiemtcb/controller-migrate:checkpoint-restore-v1` | `migrate-controller` (Checkpoint/Restore CRDs) | Lab |
| `kiemtcb/smf:v4.0.0-sdn` | SMF with SDN patch | Lab build of free5GC SMF |
| `kiemtcb/upf-test:nextmn-test-not-debug` | UPF | Lab build of NextMN UPF |
| `free5gc/*:v4.0.0` / `v4.0.1` | AMF, NRF, UDR, UDM, AUSF, PCF, NSSF, CHF, NEF, WebUI | free5GC |
| `towards5gs/free5gc-dbpython:latest` | DBPython | towards5gs-helm |
| `docker.io/bitnami/mongodb:latest` | MongoDB | Bitnami |
| `busybox:1.32.0`, `curlimages/curl:8.7.1` | Init containers | Upstream |
| `ghcr.io/kptdev/krm-functions-catalog/apply-setters:v0.2` | Setter substitution during `kpt fn render` | kpt |

Licenses of third-party material are listed in [`NOTICE`](NOTICE).

## Helper scripts (`scripts/`)

Reference only, not needed for deployment. They require Bash, Python 3 with
PyYAML, and `kubectl` (for the client-side dry run in
`render-and-validate.py`). Paths inside the scripts point to the original
build host (`/home/ubuntu/...`) and must be adjusted before reuse.
