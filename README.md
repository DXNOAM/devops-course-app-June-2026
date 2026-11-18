# Hello DevOps Flask Application

A small Flask application served by Gunicorn in Docker. The `chart` Helm
chart supports images published by Jenkins to Docker Hub and images built
locally inside Minikube.

## Endpoints

- `GET /` - displays `Hello DevOps World!`
- `GET /health` - returns `{"status":"ok"}`

The application listens on port `5001` by default. This guide uses Docker for
the complete workflow; Python and the packages in `requirements.txt` are
installed inside the image and do not need to be installed on the host.
The container runs as a non-root user.

Run commands from the project root, which contains `Dockerfile`, `app.py`,
and `chart`. Manual Helm examples use the release name `flask-monitor`;
Jenkins renders its manifest with the release name `flask-aws-monitor`.

## Jenkins image configuration

`Jenkinsfile` builds and pushes `noamyonassi/flask-aws-monitor:<BUILD_NUMBER>`
and also pushes the `latest` tag. The chart defaults to
`noamyonassi/flask-aws-monitor:latest` with `imagePullPolicy: Always`.

The pipeline passes its exact image repository and build tag to Helm:

```groovy
sh "helm template ${appname} ./chart --namespace ${qaNamespace} --set-string pod.image=${appimage} --set-string pod.tag=${apptag} > ${manifest}"
```

For example, build `42` generates a Deployment using
`noamyonassi/flask-aws-monitor:42`. On `main`, Jenkins publishes the
manifest to the GitOps repository for Argo CD to sync to QA.

The image settings for each workflow are:

| Setting | Chart default | Jenkins-generated manifest | Local Minikube arguments |
| --- | --- | --- | --- |
| `pod.image` | `noamyonassi/flask-aws-monitor` | `${appimage}` from `Jenkinsfile` | `flask-aws-monitor` |
| `pod.tag` | `latest` | `${apptag}` = Jenkins `BUILD_NUMBER` | `local` |
| `pod.pull_policy` | `Always` | `Always` | `IfNotPresent` |

`chart/values.yaml` supplies the defaults. The local Minikube commands below
override the image settings directly with `--set-string` and `--set`.
The `--set-string` arguments in Jenkins override the repository and tag
with the values used by `docker build` and `docker push`.

### Jenkins setup and stages

Configure a Jenkins Pipeline job to use the repository's `Jenkinsfile`.
It requires the Jenkins Kubernetes plugin with a configured Kubernetes
cloud that can start the agent Pod, including its privileged Docker-in-Docker
container. Add a username/password credential with the ID
`dockerhub-credentials`; use a Docker Hub username and access token with
permission to push to `noamyonassi/flask-aws-monitor`.

Add a separate username/password credential named `gitops-credentials`,
using a GitHub username and a token with write access to `DXNOAM/gitops`.
The pipeline uses the Jenkins Git tool named `Default`.

The pipeline:

1. Checks out the repository.
2. Runs a Trivy filesystem scan in parallel with building the image.
3. Scans the built image from `image.tar`.
4. Pushes the build-number tag and `latest` to Docker Hub.
5. Renders `flask-aws-monitor.yaml` using the same build-number tag.
6. For builds of the application's `main` branch, commits and pushes it to
   `workloads/qa/flask-aws-monitor/app.yaml` on `DXNOAM/gitops:main`.

`Jenkinsfile.docker` is an alternate pipeline that depends on
`my-shared-library`; it is not the pipeline described here.

The GitHub Actions workflow in `.github/workflows/trivy.yaml` also scans
the repository on pushes, pull requests, and manual runs. That scan uses
`--severity HIGH,CRITICAL --exit-code 1`. Jenkins uses Trivy's default scan
options.

### Connect Argo CD to the QA manifest

Run a successful Jenkins build of `main` first to create the manifest in
the GitOps repository. Then apply the updated `systems-qa` ApplicationSet
from that repository, or sync the Argo CD application that manages it.
The ApplicationSet must use `DXNOAM/gitops:main` and the path
`workloads/qa/flask-aws-monitor` for the Flask application.

Argo CD automatically syncs `flask-aws-monitor-qa` into the namespace of
the same name. Verify that it is `Synced` and `Healthy` and that the
Deployment uses the build tag from the Jenkins log:

```bash
kubectl -n flask-aws-monitor-qa get deployment flask-aws-monitor -o 'custom-columns=IMAGE:.spec.template.spec.containers[0].image'
```

## Prerequisites

Install Docker for your operating system and ensure the Docker daemon is
running. For Kubernetes deployment, also install `kubectl` and Helm. Install
Minikube if you want to run a local Kubernetes cluster.

On Windows, Docker Desktop must be running with Linux containers enabled.

Verify Docker before continuing:

```bash
docker version
```

## Run with Docker

```bash
docker build -t flask-aws-monitor:local .
docker run --rm -p 5001:5001 flask-aws-monitor:local
```

Keep that terminal open and browse to <http://localhost:5001>, or test the
container from another terminal:

```bash
curl http://localhost:5001
curl http://localhost:5001/health
```

On Windows PowerShell, use `curl.exe` if `curl` resolves to
`Invoke-WebRequest`.

## Deploy an image published by Jenkins

Use this workflow after a Jenkins build has successfully pushed its image.
For a local cluster, first complete step 1 of the Minikube section below.
For another Kubernetes cluster, configure `kubectl` access to that cluster.

Replace `42` in both commands below with the Jenkins build number to deploy.
Check the current context before installing:

```bash
kubectl config current-context
helm lint ./chart
helm template flask-monitor ./chart --set-string pod.image=noamyonassi/flask-aws-monitor --set-string pod.tag=42
helm upgrade --install flask-monitor ./chart --reset-values --set-string pod.image=noamyonassi/flask-aws-monitor --set-string pod.tag=42 --wait --timeout 5m
```

The rendered Deployment and installed release should use
`noamyonassi/flask-aws-monitor:42`. Verify the installed image with:

```bash
kubectl get deployment flask-monitor -o 'custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image,PULL_POLICY:.spec.template.spec.containers[0].imagePullPolicy'
kubectl rollout status deployment/flask-monitor
```

The initial install commands in this guide use `--reset-values` to select
the chart defaults plus the explicit overrides. On an existing release,
this resets previous custom settings. The configuration and update commands
below use `--reuse-values` to preserve them.

## Deploy a local image with Minikube

Run every command in this section from the directory that contains
`Dockerfile`, `app.py`, and `chart` (the project root). Ensure Docker,
Minikube, `kubectl`, and Helm are installed before continuing.

### 1. Start and verify Minikube

```bash
docker info
minikube start --driver=docker
minikube update-context
kubectl config use-context minikube
kubectl get nodes
```

The Minikube node must show `Ready` before continuing. This step is also
required when using Minikube to deploy an image published by Jenkins.

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
helm lint ./chart --set-string pod.image=flask-aws-monitor --set-string pod.tag=local --set pod.pull_policy=IfNotPresent
helm template flask-monitor ./chart --set-string pod.image=flask-aws-monitor --set-string pod.tag=local --set pod.pull_policy=IfNotPresent

helm upgrade --install flask-monitor ./chart --reset-values --set-string pod.image=flask-aws-monitor --set-string pod.tag=local --set pod.pull_policy=IfNotPresent --wait --timeout 5m
```

The informational message `Chart.yaml: icon is recommended` from `helm lint`
is not an error.

These arguments select `flask-aws-monitor:local` with
`imagePullPolicy: IfNotPresent`, so Kubernetes can use the image built inside
Minikube without pulling it from Docker Hub. Without the image overrides,
the chart uses the published `noamyonassi/flask-aws-monitor:latest` image.

### 4. Verify the Deployment

```bash
kubectl get deployment flask-monitor -o 'custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image,PULL_POLICY:.spec.template.spec.containers[0].imagePullPolicy'

kubectl get pods -l app=flask-monitor
kubectl get configmap flask-monitor-cm
kubectl rollout status deployment/flask-monitor
```

The expected image configuration is:

```text
NAME            IMAGE                     PULL_POLICY
flask-monitor   flask-aws-monitor:local   IfNotPresent
```

### 5. Access the application using ClusterIP

```bash
kubectl port-forward service/flask-monitor 5001:5001
```

Keep that terminal open and browse to <http://localhost:5001>.

### 6. Optional: expose the application with a LoadBalancer

A `LoadBalancer` Service keeps its internal `ClusterIP` access and also adds an
external address. Update the installed release while preserving its image
and other settings:

```bash
helm upgrade flask-monitor ./chart --reuse-values --set service_type=LoadBalancer
```

Run the Minikube tunnel in a separate terminal and keep it open:

```bash
minikube tunnel
```

Enter your administrator password if requested. In another terminal, wait for
the external address:

```bash
kubectl get service flask-monitor --watch
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

Enable the chart's Ingress resource on the installed release:

```bash
helm upgrade flask-monitor ./chart --reuse-values --set ingress.enabled=true
```

Wait for the Ingress to become ready:

```bash
kubectl get ingress flask-monitor --watch
```

Ingress access depends on the Minikube driver and operating system. With
the Docker driver on Windows or macOS, the Minikube node IP is not directly
reachable from the host; use the ClusterIP port-forward above for local
access. See the [Minikube networking guide](https://minikube.sigs.k8s.io/docs/handbook/accessing/)
for driver-specific access details.

On a host where the node IP is reachable, get it with `minikube ip`, then
map that IP to `flask-monitor.local` in the system hosts file. The hosts
file is usually `/etc/hosts` on Linux and macOS, and
`C:\Windows\System32\drivers\etc\hosts` on Windows. Open
<http://flask-monitor.local> after the hostname resolves to the Ingress
address. Stop the watch command with `Ctrl+C` when finished.

## Helm configuration

The main chart settings are:

| Value | Default | Purpose |
| --- | --- | --- |
| `replicas` | `2` | Number of application Pods |
| `service_type` | `ClusterIP` | `ClusterIP`, `NodePort`, or `LoadBalancer` |
| `pod.image` | `noamyonassi/flask-aws-monitor` | Image repository |
| `pod.tag` | `latest` | Image tag; Jenkins overrides this with its build number |
| `pod.pull_policy` | `Always` | Container image pull policy |
| `pod.port` | `5001` | Service port |
| `pod.target_port` | `5001` | Container port and `PORT` environment variable |
| `config.gunicorn_workers` | `2` | Gunicorn worker processes |
| `config.gunicorn_threads` | `4` | Threads per worker |
| `ingress.enabled` | `false` | Whether to create an Ingress |
| `ingress.class_name` | `nginx` | Ingress controller class |
| `ingress.host` | `flask-monitor.local` | Ingress hostname |

Inspect the values saved for the installed release:

```bash
helm get values flask-monitor --all
```

For changes to an existing release, `--reuse-values` keeps its saved image,
Service, Ingress, and other settings unless explicitly overridden. See the
[Helm upgrade reference](https://helm.sh/docs/helm/helm_upgrade/) for value
override behavior.

The `flask-monitor-cm` ConfigMap supplies `PORT`, `GUNICORN_WORKERS`, and
`GUNICORN_THREADS` to the container. To update the Gunicorn configuration
while preserving the current image, Service, and Ingress settings:

```bash
helm upgrade flask-monitor ./chart --reuse-values --set config.gunicorn_workers=3 --set config.gunicorn_threads=4
```

The Deployment checksum changes automatically when the ConfigMap changes,
so Kubernetes creates replacement Pods with the updated environment variables.

## Deploy an updated application version

### Published Jenkins image

Run Jenkins again, then replace `43` below with the new build number:

```bash
helm upgrade flask-monitor ./chart --reuse-values --set-string pod.image=noamyonassi/flask-aws-monitor --set-string pod.tag=43 --set pod.pull_policy=Always --wait --timeout 5m
kubectl rollout status deployment/flask-monitor
```

Changing `pod.tag` updates the Deployment and starts a rollout. Pushing a new
image to the registry's `latest` tag alone does not change the Deployment;
use the Jenkins build-number tag to select a specific version.

### Local Minikube image

After changing `app.py` or the Dockerfile, rebuild the image and restart the
Deployment. These commands assume the release already uses
`flask-aws-monitor:local` with `imagePullPolicy: IfNotPresent`, as configured
in the local Minikube install command above:

```bash
minikube image build -t flask-aws-monitor:local .
kubectl rollout restart deployment/flask-monitor
kubectl rollout status deployment/flask-monitor
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
kubectl get deployment flask-monitor -o 'custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image,PULL_POLICY:.spec.template.spec.containers[0].imagePullPolicy'
kubectl describe pods -l app=flask-monitor
```

For the local workflow, confirm that `flask-aws-monitor:local` was built
inside Minikube and that the release uses that image with
`imagePullPolicy: IfNotPresent`. Use the local Minikube install command above
to set all three image values. For the Jenkins workflow, confirm that the
selected build tag was pushed successfully to
`noamyonassi/flask-aws-monitor` and that the cluster can pull it.

If a Pod shows `CrashLoopBackOff`, inspect its events and previous logs:

```bash
kubectl describe pods -l app=flask-monitor
kubectl logs -l app=flask-monitor --all-containers=true --prefix --previous --tail=100
```

## Rollback

Choose a previous revision from `helm history`, then replace `REVISION`
with that number:

```bash
helm history flask-monitor
helm rollback flask-monitor REVISION
kubectl rollout status deployment/flask-monitor
```

The rollback restores the Helm revision's configuration, including its
image tag. Keep the corresponding image available in Docker Hub or the
Minikube image store so replacement Pods can start with that version.

When a tag such as `local` or `latest` is reused for different builds, Helm
cannot restore its previous image contents. Use distinct version tags when
you need to roll back the application image.
