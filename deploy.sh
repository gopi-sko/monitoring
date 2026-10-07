#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }

# ── Pre-flight ─────────────────────────────────────────────────────────────────
command -v kubectl >/dev/null || { echo "kubectl not found"; exit 1; }
command -v minikube >/dev/null || { echo "minikube not found"; exit 1; }

if ! minikube status | grep -q "Running"; then
  warn "Minikube is not running. Starting..."
  minikube start --memory=4096 --cpus=2
fi

# ── Namespaces ─────────────────────────────────────────────────────────────────
info "Creating namespaces..."
kubectl apply -f apps/namespace.yaml
kubectl apply -f monitoring/namespace.yaml

# ── Sample Apps ────────────────────────────────────────────────────────────────
info "Deploying sample apps..."
kubectl apply -f apps/pvc.yaml
kubectl apply -f apps/deployment.yaml

# ── Monitoring stack ───────────────────────────────────────────────────────────
info "Deploying node-exporter..."
kubectl apply -f monitoring/node-exporter/daemonset.yaml
kubectl apply -f monitoring/node-exporter/service.yaml

info "Deploying kube-state-metrics..."
kubectl apply -f monitoring/kube-state-metrics/rbac.yaml
kubectl apply -f monitoring/kube-state-metrics/deployment.yaml
kubectl apply -f monitoring/kube-state-metrics/service.yaml

info "Deploying AlertManager..."
kubectl apply -f monitoring/alertmanager/configmap.yaml
kubectl apply -f monitoring/alertmanager/deployment.yaml
kubectl apply -f monitoring/alertmanager/service.yaml

info "Deploying Prometheus..."
kubectl apply -f monitoring/prometheus/rbac.yaml
kubectl apply -f monitoring/prometheus/configmap.yaml
kubectl apply -f monitoring/prometheus/deployment.yaml
kubectl apply -f monitoring/prometheus/service.yaml

info "Deploying Loki..."
kubectl apply -f monitoring/loki/configmap.yaml
kubectl apply -f monitoring/loki/deployment.yaml
kubectl apply -f monitoring/loki/service.yaml

info "Deploying Promtail..."
kubectl apply -f monitoring/promtail/rbac.yaml
kubectl apply -f monitoring/promtail/configmap.yaml
kubectl apply -f monitoring/promtail/daemonset.yaml

info "Loading Grafana dashboards from monitoring/grafana/dashboards/..."
DASH=monitoring/grafana/dashboards
# All dashboards use fixed UIDs: prometheus-uid / loki-uid (set in grafana/configmap.yaml)
# kubectl create configmap + --dry-run=client -o yaml | kubectl apply handles create-or-update
# The 1860 node-exporter dashboard (458K) is too large for kubectl apply annotation overhead
# so we delete+create it. All others use the standard idempotent apply pattern.
kubectl create configmap grafana-dashboard-loki       --from-file=13186_rev1.json=$DASH/13186_rev1.json   -n monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap grafana-dashboard-blackbox   --from-file=13659_rev1.json=$DASH/13659_rev1.json   -n monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap grafana-dashboard-k8s        --from-file=15661_rev2.json=$DASH/15661_rev2.json   -n monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap grafana-dashboard-pods       --from-file=15760_rev39.json=$DASH/15760_rev39.json -n monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap grafana-dashboard-kubernetes --from-file=21299_rev1.json=$DASH/21299_rev1.json   -n monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap grafana-dashboard-deployment --from-file=741_rev1.json=$DASH/741_rev1.json       -n monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl delete configmap grafana-dashboard-node -n monitoring --ignore-not-found
kubectl create configmap grafana-dashboard-node       --from-file=1860_rev45.json=$DASH/1860_rev45.json   -n monitoring

info "Deploying Grafana..."
kubectl apply -f monitoring/grafana/configmap.yaml
kubectl apply -f monitoring/grafana/deployment.yaml
kubectl apply -f monitoring/grafana/service.yaml

# ── Wait for pods ──────────────────────────────────────────────────────────────
info "Waiting for monitoring pods to be ready..."
kubectl rollout status deployment/prometheus         -n monitoring --timeout=120s
kubectl rollout status deployment/alertmanager       -n monitoring --timeout=120s
kubectl rollout status deployment/grafana            -n monitoring --timeout=120s
kubectl rollout status deployment/kube-state-metrics -n monitoring --timeout=120s
kubectl rollout status deployment/loki               -n monitoring --timeout=120s
kubectl rollout status daemonset/promtail            -n monitoring --timeout=120s

# ── Print URLs ─────────────────────────────────────────────────────────────────
MINIKUBE_IP=$(minikube ip)
echo ""
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Deployment complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo ""
echo "  Sample app:    http://${MINIKUBE_IP}:$(kubectl get svc nginx-sample -nopenedx -o jsonpath='{.spec.ports[0].nodePort}')"
echo "  Prometheus:    http://${MINIKUBE_IP}:30090"
echo "  AlertManager:  http://${MINIKUBE_IP}:30093"
echo "  Grafana:       http://${MINIKUBE_IP}:30030   (admin / admin123)"
echo "  Loki:          http://${MINIKUBE_IP}:30310"
echo ""
warn "IMPORTANT: Edit monitoring/alertmanager/configmap.yaml and set your SMTP credentials."
warn "Then run: kubectl apply -f monitoring/alertmanager/configmap.yaml && kubectl rollout restart deployment/alertmanager -n monitoring"
echo ""
