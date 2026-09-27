# Zuri Platform — DevOps Capstone

End-to-end DevOps platform for Zuri Market, a two-service Node.js/React e-commerce application. Covers containerization, infrastructure as code, CI/CD, Kubernetes, and monitoring.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    GitHub Actions                    │
│         CI (build/test/scan/push) per repo          │
│         CD (deploy to EC2 via SSM) on main          │
└──────────────────────┬──────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          │                         │
   ┌──────▼──────┐          ┌───────▼──────┐
   │  Kubernetes  │          │     EC2      │
   │  (Minikube)  │          │  (us-east-2) │
   │              │          │              │
   │  frontend    │          │  frontend:80 │
   │  backend     │          │  backend:5000│
   │  ingress     │          │  docker      │
   │  prometheus  │          │  compose     │
   │  grafana     │          └──────────────┘
   └──────────────┘
```

## Repositories

| Repo | Description |
|------|-------------|
| [zuriapp-backend](https://github.com/silverngopang/zuriapp-backend) | Express REST API |
| [zuriapp-frontend](https://github.com/silverngopang/zuriapp-frontend) | React/Vite frontend |
| [zuri-platform](https://github.com/silverngopang/zuri-platform) | Infrastructure, K8s, CI/CD |

## Services

- **Backend** — Express API on port 5000. Routes: `GET /api/store`, `GET /api/products`, `GET /api/products/:id`, `POST /api/cart/validate`, `GET /metrics`
- **Frontend** — React/Vite app served via nginx on port 80

## Prerequisites

- Docker
- kubectl + Minikube
- Helm v3
- Terraform >= 1.0
- AWS CLI configured (`us-east-2`)

## Local Development

```bash
# Backend
cd zuriapp-backend
cp .env.example .env
npm install
npm run dev        # http://localhost:5000

# Frontend
cd zuriapp-frontend
cp .env.example .env
npm install
npm run dev        # http://localhost:3000
```

## Docker Compose

```bash
cd zuri-platform
docker compose up
# frontend → http://localhost:8080
# backend  → http://localhost:5000
```

## Infrastructure (Terraform)

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

Resources provisioned:
- VPC with public/private subnets in `us-east-2`
- EC2 `t3.micro` with Docker and Docker Compose
- IAM role with SSM and Secrets Manager permissions
- Security group (ports 80, 5000)

State stored in S3: `zuri-terraform-state-820765098114`

## Kubernetes (Minikube)

```bash
minikube start
minikube addons enable ingress

# Apply all manifests
kubectl apply -f k8s/backend/
kubectl apply -f k8s/frontend/
kubectl apply -f k8s/rbac/
kubectl apply -f k8s/ingress.yaml

# Add to /etc/hosts
echo "$(minikube ip) zuri.local" | sudo tee -a /etc/hosts

# Access via minikube service tunnel
minikube service ingress-nginx-controller -n ingress-nginx --url
curl -H "Host: zuri.local" http://127.0.0.1:<PORT>/api/store
```

### K8s Resources

| Resource | Description |
|----------|-------------|
| Deployment | backend, frontend |
| Service | ClusterIP for backend (5000) and frontend (80) |
| ConfigMap | PORT, STORE_NAME |
| Secret | API_SECRET_KEY |
| Ingress | nginx, routes /api → backend, / → frontend |
| ServiceAccount | backend-sa, frontend-sa |
| RBAC | Least-privilege roles for each service |

## CI/CD

### CI Pipeline (per app repo)

Triggered on push to any branch:
1. Lint (ESLint)
2. Test (Jest)
3. Docker build
4. Trivy security scan
5. Push to Docker Hub (main branch only)

### CD Pipeline (zuri-platform)

Triggered on push to main:
1. Write `docker-compose.yml` to EC2 via AWS SSM
2. Pull latest images from Docker Hub
3. Restart containers with `docker compose up -d`

### GitHub Secrets Required

**App repos (zuriapp-backend, zuriapp-frontend):**
| Secret | Description |
|--------|-------------|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |

**zuri-platform:**
| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `API_SECRET_KEY` | Backend API secret |

## Monitoring

Prometheus + Grafana deployed via Helm on Minikube.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin123

# Access Grafana
kubectl --namespace monitoring port-forward svc/monitoring-grafana 3000:80
# http://127.0.0.1:3000  admin / admin123

# Access Prometheus
kubectl --namespace monitoring port-forward svc/prometheus-operated 9090:9090
# http://127.0.0.1:9090
```

Backend exposes Prometheus metrics at `/metrics` using `prom-client`. A ServiceMonitor scrapes it every 30 seconds.

Useful queries:
```promql
# Request rate per route
rate(http_requests_total[1m])

# Total requests by route
http_requests_total{job="backend"}
```

## Docker Images

| Image | Docker Hub |
|-------|------------|
| Backend | `silverspark/zuriapp-backend:latest` |
| Frontend | `silverspark/zuriapp-frontend:latest` |
