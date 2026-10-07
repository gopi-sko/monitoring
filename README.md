# Minikube Monitoring Stack

Prometheus + Grafana + AlertManager on Minikube with email alerts at >80% CPU / Memory / Disk.

## Folder Structure

```
Prometheus/
├── deploy.sh                        # one-shot deploy
├── teardown.sh                      # clean everything
├── apps/
│   ├── namespace.yaml               # namespace: 
│   ├── deployment.yaml              # nginx (2 replicas) + NodePort service
│   └── pvc.yaml                     # 512Mi PVC
└── monitoring/
    ├── namespace.yaml               # namespace: monitoring
    ├── node-exporter/               # node CPU / memory / disk metrics
    ├── kube-state-metrics/          # Kubernetes object metrics
    ├── prometheus/                  # metrics store + alert rules
    ├── alertmanager/                # email routing
    └── grafana/                     # dashboards (Prometheus datasource auto-wired)
```

## Quick Start

### 1. Set SMTP credentials (required for email alerts)

Edit `monitoring/alertmanager/configmap.yaml` and fill in the three placeholders:

```yaml
smtp_smarthost: 'smtp.gmail.com:587'       # or smtp.office365.com:587
smtp_from: 'your-sender@gmail.com'
smtp_auth_username: 'your-sender@gmail.com'
smtp_auth_password: 'your-app-password'    # Gmail: 16-char App Password
```

> For Gmail, create an App Password at https://myaccount.google.com/apppasswords
> (requires 2FA to be enabled on the sender account).

Alerts are sent to **gopinaath.c@skillup.online** — change `to:` in the same file if needed.

### 2. Deploy

```bash
cd /Users/gopi-sko/Desktop/Prometheus
./deploy.sh
```

### 3. Access UIs

| Service      | URL                             | Credentials    |
|--------------|---------------------------------|----------------|
| Prometheus   | http://<minikube-ip>:30090      | —              |
| AlertManager | http://<minikube-ip>:30093      | —              |
| Grafana      | http://<minikube-ip>:30030      | admin / admin123 |
| Sample app   | printed by deploy.sh            | —              |

Get `<minikube-ip>` with: `minikube ip`

Or use minikube service tunnels:
```bash
minikube service prometheus    -n monitoring
minikube service grafana       -n monitoring
minikube service alertmanager  -n monitoring
```

### 4. Grafana dashboards (import)

1. Open Grafana → **Dashboards → Import**
2. Enter dashboard ID and click **Load**:

| Dashboard                  | ID    |
|----------------------------|-------|
| Node Exporter Full         | 1860  |
| Kubernetes Cluster Overview| 7249  |
| Kubernetes Pods            | 6417  |

Datasource: select **Prometheus** (pre-wired).

## Alert Rules

| Alert            | Condition                  | Wait |
|------------------|----------------------------|------|
| HighCPUUsage     | CPU > 80% (idle metric)    | 2m   |
| HighMemoryUsage  | RAM used > 80%             | 2m   |
| HighDiskUsage    | Disk `/` > 80%             | 2m   |
| PVCUsageHigh     | PVC bytes > 80%            | 2m   |
| PodCrashLooping  | restart_total > 5          | 5m   |

Fired alerts appear in AlertManager UI and are emailed to the address configured above.

## Accessing Components

### Option A — minikube service (opens browser automatically)

```bash
minikube service prometheus    -n monitoring
minikube service alertmanager  -n monitoring
minikube service grafana       -n monitoring
minikube service nginx-sample  -nopenedx
```

### Option B — fixed NodePort URLs

```bash
MINIKUBE_IP=$(minikube ip)
echo "Prometheus   → http://$MINIKUBE_IP:30090"
echo "AlertManager → http://$MINIKUBE_IP:30093"
echo "Grafana      → http://$MINIKUBE_IP:30030"
```

| Component    | NodePort URL              | Login            |
|--------------|---------------------------|------------------|
| Prometheus   | `http://<ip>:30090`       | —                |
| AlertManager | `http://<ip>:30093`       | —                |
| Grafana      | `http://<ip>:30030`       | admin / admin123 |
| Sample app   | printed by `deploy.sh`    | —                |

### Prometheus — useful pages

| Page              | Path       |
|-------------------|------------|
| Scrape targets    | `/targets` |
| Alert rules       | `/rules`   |
| Fired alerts      | `/alerts`  |
| Query explorer    | `/graph`   |

## Logs

```bash
# Prometheus
kubectl logs -n monitoring deployment/prometheus -f

# AlertManager
kubectl logs -n monitoring deployment/alertmanager -f

# Grafana
kubectl logs -n monitoring deployment/grafana -f

# Node exporter
kubectl logs -n monitoring daemonset/node-exporter -f

# kube-state-metrics
kubectl logs -n monitoring deployment/kube-state-metrics -f

# Sample nginx app
kubectl logs -nopenedx deployment/nginx-sample -f
```

## Pod & Resource Status

```bash
# All monitoring pods
kubectl get pods -n monitoring

# All sample-app pods
kubectl get pods -nopenedx

# Services with NodePorts
kubectl get svc -n monitoring
```

## Update SMTP after deploy

```bash
kubectl apply -f monitoring/alertmanager/configmap.yaml
kubectl rollout restart deployment/alertmanager -n monitoring
```

## Teardown

```bash
./teardown.sh
```
