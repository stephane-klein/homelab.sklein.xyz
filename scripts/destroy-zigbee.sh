#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

NAMESPACE="zigbee"

echo "=== Destroying MQTT bridge ==="
kubectl delete deployment mqtt-bridge -n "$NAMESPACE" --ignore-not-found > /dev/null
kubectl delete configmap mqtt-bridge -n "$NAMESPACE" --ignore-not-found > /dev/null

echo "=== Destroying Mosquitto + Zigbee2MQTT ==="
helm uninstall mosquitto --namespace "$NAMESPACE" --ignore-not-found > /dev/null
helm uninstall zigbee2mqtt --namespace "$NAMESPACE" --ignore-not-found > /dev/null

kubectl delete namespace "$NAMESPACE" --ignore-not-found > /dev/null

echo "=== Done ==="
