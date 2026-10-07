#!/usr/bin/env bash
set -euo pipefail

echo "Deleting sample apps..."
kubectl delete -f apps/ --ignore-not-found

echo "Deleting monitoring stack..."
kubectl delete -f monitoring/grafana/      --ignore-not-found
kubectl delete -f monitoring/loki/         --ignore-not-found
kubectl delete -f monitoring/promtail/     --ignore-not-found
kubectl delete -f monitoring/prometheus/   --ignore-not-found
kubectl delete -f monitoring/alertmanager/ --ignore-not-found
kubectl delete -f monitoring/kube-state-metrics/ --ignore-not-found
kubectl delete -f monitoring/node-exporter/      --ignore-not-found
kubectl delete -f monitoring/cadvisor/           --ignore-not-found
kubectl delete -f monitoring/namespace.yaml --ignore-not-found

echo "Done."
