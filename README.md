# Hello DevOps Flask Application

A small Flask application packaged with Docker and deployed to Kubernetes with
the `helmchart` Helm chart.

## Endpoints

- `GET /` - displays `Hello DevOps World!`
- `GET /health` - liveness and readiness endpoint

The application listens on port `5001` by default.

## Run directly on Ubuntu

From the project directory:

```bash
sudo apt update
sudo apt install -y python3 python3-venv python3-pip

python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
PORT=5001 python app.py
```

Open <http://localhost:5001> or test from the terminal:

```bash
curl http://localhost:5001
curl http://localhost:5001/health
```

## Run with Docker

```bash
docker build -t flask-aws-monitor:local .
docker run --rm -p 5001:5001 flask-aws-monitor:local
```

## Deploy locally with Minikube and Helm

Run every command in this section from the directory that contains
`Dockerfile`, `app.py`, and `helmchart`. For the path shown in the Ubuntu
screenshots:

```bash
cd "$HOME/Devops Project/app for devops"
```

### 1. Start and verify Minikube

```bash
sudo systemctl start docker
minikube start --driver=docker
minikube update-context
kubectl config use-context minikube
kubectl get nodes
```

The Minikube node must show `Ready` before continuing.

### 2. Build the image inside Minikube

```bash
minikube image build -t flask-aws-monitor:local .
minikube image ls | grep flask-aws-monitor
```

Expected image:

```text
docker.io/library/flask-aws-monitor:local
```

### 3. Validate and install the Helm chart

```bash
helm lint ./helmchart
helm template flask-monitor ./helmchart \
  --values ./helmchart/minikube-values.yaml

helm upgrade --install flask-monitor ./helmchart \
  --reset-values \
  --values ./helmchart/minikube-values.yaml
```

The informational message `Chart.yaml: icon is recommended` from `helm lint`
is not an error.

### 4. Verify the Deployment

```bash
kubectl get deployment flask-monitor-flask-aws-monitor \
  -o jsonpath='{.spec.template.spec.containers[0].image}{" "}{.spec.template.spec.containers[0].imagePullPolicy}{"\n"}'

kubectl get pods
kubectl rollout status deployment/flask-monitor-flask-aws-monitor
```

The expected image configuration is:

```text
flask-aws-monitor:local IfNotPresent
```

### 5. Access the application using ClusterIP

```bash
kubectl port-forward \
  service/flask-monitor-flask-aws-monitor \
  5001:5001
```

Keep that terminal open and browse to <http://localhost:5001>.

### 6. Optional: expose the application with a LoadBalancer

A `LoadBalancer` Service keeps its internal `ClusterIP` access and also adds an
external address. Install or update the release with:

```bash
helm upgrade --install flask-monitor ./helmchart \
  --reset-values \
  --values ./helmchart/minikube-values.yaml \
  --set service.type=LoadBalancer
```

Run the Minikube tunnel in a separate terminal and keep it open:

```bash
minikube tunnel
```

Enter the Ubuntu password if requested. In another terminal, wait for the
external address:

```bash
kubectl get service flask-monitor-flask-aws-monitor --watch
```

When the `EXTERNAL-IP` column is no longer `<pending>`, press `Ctrl+C` to stop
watching and print the application URL:

```bash
EXTERNAL_IP=$(kubectl get service flask-monitor-flask-aws-monitor \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "http://${EXTERNAL_IP}:5001"
curl "http://${EXTERNAL_IP}:5001/health"
```

If `EXTERNAL-IP` remains `<pending>`, confirm that `minikube tunnel` is still
running. Stop a failed tunnel with `Ctrl+C`, then restart it with diagnostic
output:

```bash
minikube tunnel --cleanup --alsologtostderr -v=4
```

The tunnel must remain running while the external address is in use.

## Deploy an updated application version

After changing `app.py` or the Dockerfile, rebuild the image and restart the
Deployment:

```bash
minikube image build -t flask-aws-monitor:local .
kubectl rollout restart deployment/flask-monitor-flask-aws-monitor
kubectl rollout status deployment/flask-monitor-flask-aws-monitor
```

## Deploy with an image from Docker Hub

Replace `DOCKERHUB_USERNAME` with your Docker Hub username:

```bash
docker build -t DOCKERHUB_USERNAME/flask-aws-monitor:latest .
docker login
docker push DOCKERHUB_USERNAME/flask-aws-monitor:latest

helm upgrade --install flask-monitor ./helmchart \
  --reset-values \
  --set-string image.repository=DOCKERHUB_USERNAME/flask-aws-monitor \
  --set-string image.tag=latest \
  --set image.pullPolicy=Always
```

## Troubleshooting

If Kubernetes is unreachable:

```bash
sudo systemctl start docker
minikube start --driver=docker
minikube update-context
kubectl config use-context minikube
kubectl get nodes
```

If a Pod shows `ImagePullBackOff`, compare the available and configured images:

```bash
minikube image ls | grep flask-aws-monitor
kubectl get deployment flask-monitor-flask-aws-monitor \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

If a Pod shows `CrashLoopBackOff`, inspect its events and previous logs:

```bash
kubectl describe pods -l app.kubernetes.io/instance=flask-monitor
kubectl logs -l app.kubernetes.io/instance=flask-monitor \
  --all-containers=true --prefix --previous --tail=100
```

The chart keeps the container root filesystem read-only and mounts a writable
temporary `emptyDir` volume at `/tmp` for Gunicorn.

## Upgrade and rollback

```bash
helm history flask-monitor
helm upgrade flask-monitor ./helmchart --reuse-values
helm rollback flask-monitor REVISION
```
