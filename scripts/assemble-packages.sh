#!/bin/bash
set -euo pipefail

SRC_CATALOG=/home/ubuntu/nephio-free5gc-migration/nephio-free5gc-catalog
SRC_UPFMIG=/home/ubuntu/upf-migrate
SRC_LOCAL=/home/ubuntu/nephio-packages/_src   # small hand-authored files staged here beforehand
OUT=/home/ubuntu/nephio-packages

rm -rf "$OUT/free5gc-5gcore-others" "$OUT/free5gc-amf-smf-upf" "$OUT/5g-controllers"
mkdir -p "$OUT/free5gc-5gcore-others/resources"
mkdir -p "$OUT/free5gc-amf-smf-upf/resources"
mkdir -p "$OUT/5g-controllers/resources"

# ---------- Package 1: free5gc-5gcore-others ----------
P1="$OUT/free5gc-5gcore-others/resources"
cp "$SRC_CATALOG/free5gc-common/resources/free5gc-common.yaml" "$P1/00-common.yaml"
cp "$SRC_LOCAL/pv-cert-definition.yaml" "$P1/01-pv-cert.yaml"
cp "$SRC_LOCAL/pv-mongo-definition.yaml" "$P1/02-pv-mongo.yaml"
cp "$SRC_CATALOG/free5gc-mongodb/resources/free5gc-mongodb.yaml" "$P1/10-mongodb.yaml"
cp "$SRC_CATALOG/free5gc-nrf/resources/free5gc-nrf.yaml" "$P1/20-nrf.yaml"
cp "$SRC_CATALOG/free5gc-udr/resources/free5gc-udr.yaml" "$P1/21-udr.yaml"
cp "$SRC_CATALOG/free5gc-udm/resources/free5gc-udm.yaml" "$P1/22-udm.yaml"
cp "$SRC_CATALOG/free5gc-ausf/resources/free5gc-ausf.yaml" "$P1/23-ausf.yaml"
cp "$SRC_CATALOG/free5gc-pcf/resources/free5gc-pcf.yaml" "$P1/24-pcf.yaml"
cp "$SRC_CATALOG/free5gc-nssf/resources/free5gc-nssf.yaml" "$P1/25-nssf.yaml"
cp "$SRC_CATALOG/free5gc-chf/resources/free5gc-chf.yaml" "$P1/26-chf.yaml"
cp "$SRC_CATALOG/free5gc-nef/resources/free5gc-nef.yaml" "$P1/27-nef.yaml"
cp "$SRC_CATALOG/free5gc-dbpython/resources/free5gc-dbpython.yaml" "$P1/28-dbpython.yaml"
cp "$SRC_CATALOG/free5gc-webui/resources/free5gc-webui.yaml" "$P1/30-webui.yaml"

# ---------- Package 2: free5gc-amf-smf-upf ----------
P2="$OUT/free5gc-amf-smf-upf/resources"
cp "$SRC_CATALOG/free5gc-amf/resources/free5gc-amf.yaml" "$P2/10-amf.yaml"
cp "$SRC_CATALOG/free5gc-smf/resources/free5gc-smf.yaml" "$P2/20-smf.yaml"
cp "$SRC_LOCAL/config-upf.yaml" "$P2/30-upf-configmap.yaml"
cp "$SRC_LOCAL/session-manager-config.yaml" "$P2/31-upf-session-manager-configmap.yaml"
cp "$SRC_LOCAL/pod-upf.yaml" "$P2/32-upf-pod.yaml"
cp "$SRC_LOCAL/n3-conf.yaml" "$P2/33-upf-n3-nad.yaml"
cp "$SRC_LOCAL/n4-conf.yaml" "$P2/34-upf-n4-nad.yaml"
cp "$SRC_LOCAL/n6-conf.yaml" "$P2/35-upf-n6-nad.yaml"

# ---------- Package 3: 5g-controllers ----------
P3="$OUT/5g-controllers/resources"
cp "$SRC_LOCAL/agent-controller.yaml" "$P3/10-agent.yaml"
cp "$SRC_LOCAL/migrate-controller.yaml" "$P3/20-migrate-controller.yaml"
cp "$SRC_UPFMIG/config/enipool-manager/deployment.yaml" "$P3/30-enipool-manager.yaml"
cat "$SRC_UPFMIG/config/crd/bases/upf.ahihi.ahuhu_migrates.yaml" \
    "$SRC_UPFMIG/config/crd/bases/upf.ahihi.ahuhu_registrations.yaml" \
    "$SRC_UPFMIG/config/crd/bases/upf.ahihi.ahuhu_nextmnupfmaps.yaml" \
    > "$P3/01-crds-migrate.yaml"
cat "$SRC_UPFMIG/config/crd/bases/upf.ahihi.ahuhu_cloudnicpools.yaml" \
    "$SRC_UPFMIG/config/crd/bases/upf.ahihi.ahuhu_cloudnicclaims.yaml" \
    "$SRC_UPFMIG/config/crd/bases/upf.ahihi.ahuhu_ippools.yaml" \
    > "$P3/02-crds-enipool.yaml"

echo "DONE assembling raw resources"
find "$OUT" -type f | sort
