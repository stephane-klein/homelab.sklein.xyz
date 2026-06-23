#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="zigbee"

echo "=== Deploying Mosquitto + Zigbee2MQTT via Helmfile ==="

helmfile -f helmfile/helmfile.yaml.gotmpl apply

echo ""
echo "=== Deploying MQTT → VictoriaMetrics bridge ==="

kubectl create configmap mqtt-bridge -n "$NAMESPACE" \
  --from-file=bridge.py=config/zigbee/bridge.py \
  --dry-run=client -o yaml | kubectl apply -f - > /dev/null

kubectl apply -n "$NAMESPACE" -f manifests/zigbee/

echo ""
echo "  Waiting for Zigbee2MQTT to be ready..."
kubectl wait --for=condition=Ready pod \
  -n "$NAMESPACE" -l app.kubernetes.io/instance=zigbee2mqtt \
  --timeout=120s > /dev/null

echo "  Waiting for Mosquitto to be ready..."
kubectl wait --for=condition=Ready pod \
  -n "$NAMESPACE" -l app.kubernetes.io/instance=mosquitto \
  --timeout=120s > /dev/null

echo ""
echo "=== Done ==="
echo "  Mosquitto : mosquitto.zigbee.svc.cluster.local:1883"
echo "  Zigbee2MQTT UI : https://zigbee2mqtt.sklein.internal"
echo "  Bridge : mqtt-bridge deployment in namespace $NAMESPACE"
