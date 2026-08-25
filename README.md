# Hello DevOps Flask Application

A small Flask application packaged with Docker and deployed to Kubernetes with
the `helmchart` Helm chart.

## Endpoints

- `GET /` - displays `Hello DevOps World!`
- `GET /health` - liveness and readiness endpoint

The application listens on port `5001` by default.

## Run directly with Python

Python 3 with `venv` support is required. From the project root, create a
virtual environment:

```bash
python -m venv .venv
```

Use `python3` instead of `python` if that is the Python executable on your
system. Activate the virtual environment on Linux or macOS:

```bash
source .venv/bin/activate
```

Or activate it in Windows PowerShell:

```powershell
.venv\Scripts\Activate.ps1
```

Then install the dependencies and run the application:

```bash
python -m pip install -r requirements.txt
python app.py
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
`Dockerfile`, `app.py`, and `helmchart` (the project root). Ensure Docker,
Minikube, `kubectl`, and Helm are installed before continuing.

### 1. Start and verify Minikube

```bash
docker info
minikube start --driver=docker
minikube update-context
kubectl config use-context minikube
kubectl get nodes
```

The Minikube node must show `Ready` before continuing.

### 2. Build the image inside Minikube

```bash
minikube image build -t flask-aws-monitor:local .
minikube image ls
```

Expected image:

```text
docker.io/library/flask-aws-monitor:local
```

### 3. Validate and install the Helm chart

```bash
helm lint ./helmchart
helm template flask-monitor ./helmchart

helm upgrade --install flask-monitor ./helmchart --reset-values
```

The informational message `Chart.yaml: icon is recommended` from `helm lint`
is not an error.

### 4. Verify the Deployment

```bash
kubectl get deployment flask-monitor-flask-aws-monitor -o jsonpath='{.spec.template.spec.containers[0].image}{" "}{.spec.template.spec.containers[0].imagePullPolicy}{"\n"}'

kubectl get pods
kubectl rollout status deployment/flask-monitor-flask-aws-monitor
```

The expected image configuration is:

```text
flask-aws-monitor:local IfNotPresent
```

### 5. Access the application using ClusterIP

```bash
kubectl port-forward service/flask-monitor-flask-aws-monitor 5001:5001
```

Keep that terminal open and browse to <http://localhost:5001>.

### 6. Optional: expose the application with a LoadBalancer

A `LoadBalancer` Service keeps its internal `ClusterIP` access and also adds an
external address. Install or update the release with:

```bash
helm upgrade --install flask-monitor ./helmchart --reset-values --set service_type=LoadBalancer
```

Run the Minikube tunnel in a separate terminal and keep it open:

```bash
minikube tunnel
```

Enter your administrator password if requested. In another terminal, wait for
the external address:

```bash
kubectl get service flask-monitor-flask-aws-monitor --watch
```

When the `EXTERNAL-IP` column is no longer `<pending>`, press `Ctrl+C` to stop
watching. Replace `YOUR_EXTERNAL_IP` below with the displayed address:

```bash
curl http://YOUR_EXTERNAL_IP:5001/health
```

Open `http://YOUR_EXTERNAL_IP:5001` in a browser.

If `EXTERNAL-IP` remains `<pending>`, confirm that `minikube tunnel` is still
running. Stop a failed tunnel with `Ctrl+C`, then restart it with diagnostic
output:

```bash
minikube tunnel --cleanup --alsologtostderr -v=4
```

The tunnel must remain running while the external address is in use.

### 7. Optional: expose the application with Ingress

An Ingress controller is required. For Minikube, enable its Ingress addon:

```bash
minikube addons enable ingress
```

Enable the chart's Ingress resource:

```bash
helm upgrade --install flask-monitor ./helmchart --reset-values --set ingress.enabled=true
```

Wait for the Ingress to become ready:

```bash
kubectl get ingress flask-monitor-flask-aws-monitor --watch
```

The default hostname is `flask-monitor.local`. Get the Minikube IP with
`minikube ip`, then map that IP to `flask-monitor.local` in the system hosts
file. The hosts file is usually `/etc/hosts` on Linux and macOS, and
`C:\Windows\System32\drivers\etc\hosts` on Windows.

Open <http://flask-monitor.local> after the hostname resolves to the Ingress
address. Ingress availability depends on the Minikube driver and operating
system.

## Deploy an updated application version

After changing `app.py` or the Dockerfile, rebuild the image and restart the
Deployment:

```bash
minikube image build -t flask-aws-monitor:local .
kubectl rollout restart deployment/flask-monitor-flask-aws-monitor
kubectl rollout status deployment/flask-monitor-flask-aws-monitor
```

## Troubleshooting

If Kubernetes is unreachable:

```bash
docker info
minikube start --driver=docker
minikube update-context
kubectl config use-context minikube
kubectl get nodes
```

If a Pod shows `ImagePullBackOff`, compare the available and configured images:

```bash
minikube image ls
kubectl get deployment flask-monitor-flask-aws-monitor -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

If a Pod shows `CrashLoopBackOff`, inspect its events and previous logs:

```bash
kubectl describe pods -l app.kubernetes.io/instance=flask-monitor
kubectl logs -l app.kubernetes.io/instance=flask-monitor --all-containers=true --prefix --previous --tail=100
```

The chart keeps the container root filesystem read-only and mounts a writable
temporary `emptyDir` volume at `/tmp` for Gunicorn.

## Upgrade and rollback

```bash
helm history flask-monitor
helm upgrade flask-monitor ./helmchart --reuse-values
helm rollback flask-monitor REVISION
```
