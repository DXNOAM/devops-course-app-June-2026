def appname = "flask-aws-monitor"
def repo = "noamyonassi"
def appimage = "${repo}/${appname}"
def apptag = "${env.BUILD_NUMBER}"
def qaNamespace = "${appname}-qa"
def manifest = "${appname}.yaml"
def gitopsRepo = 'https://github.com/DXNOAM/gitops.git'
def gitopsBranch = 'main'
def gitopsManifest = "workloads/qa/${appname}/app.yaml"
def sourceBranch

podTemplate(containers: [
      containerTemplate(name: 'jnlp', image: 'jenkins/inbound-agent', ttyEnabled: true),
      containerTemplate(name: 'docker', image: 'docker:dind', ttyEnabled: true, privileged: true),
      containerTemplate(name: 'trivy', image: 'aquasec/trivy:latest', command: 'cat', ttyEnabled: true),
      containerTemplate(name: 'helm', image: 'alpine/helm:latest', command: 'cat', ttyEnabled: true)
  ])
  {
    node(POD_LABEL) {
        stage('checkout') {
            container('jnlp') {
              sh '/usr/bin/git config --global http.sslVerify false'
              def scmVars = checkout scm
              sourceBranch = env.BRANCH_NAME ?: scmVars.GIT_BRANCH
            }
        } // end checkout

        parallel(
            'FS Scan': {
                stage('FS Scan') {
                    container('trivy') {
                        echo "Running Trivy File System scan..."
                        sh "trivy fs ."
                    }
                }
            },
            'Build': {
                stage('Build Image') {
                    container('docker') {
                        echo "Waiting for Docker daemon to start..."
                        sleep 5
                        
                        echo "Building docker image..."
                        sh "docker build -t ${appimage}:${apptag} ."
                        sh "docker tag ${appimage}:${apptag} ${appimage}:latest"
                        
                        echo "Saving image to tarball for scanning..."
                        sh "docker save -o image.tar ${appimage}:${apptag}"
                    }
                }
            }
        ) // end parallel

        stage('Image Scan') {
            container('trivy') {
                echo "Running Trivy Image scan..."
                sh "trivy image --input image.tar"
            }
        } // end image scan

        stage('push') {
            container('docker') {
              echo "Pushing docker image to DockerHub..."
              withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME')]) {
                  sh "echo \$DOCKER_PASSWORD | docker login -u \$DOCKER_USERNAME --password-stdin"
                  sh "docker push ${appimage}:${apptag}"
                  sh "docker push ${appimage}:latest"
              }
            }
        } //end push

        stage('Render Helm manifest') {
            container('helm') {
                echo "Generating Helm template..."
                sh "helm template ${appname} ./chart --namespace ${qaNamespace} --set-string pod.image=${appimage} --set-string pod.tag=${apptag} > ${manifest}"
            }
        }

        stage('Publish QA manifest') {
            def mainBranches = ['main', 'origin/main', 'refs/heads/main', 'refs/remotes/origin/main']
            if (env.CHANGE_ID || !mainBranches.contains(sourceBranch)) {
                echo "Skipping QA publication for ${sourceBranch ?: 'an unknown branch'}"
                return
            }

            container('jnlp') {
                withEnv([
                    "GITOPS_REPO=${gitopsRepo}",
                    "GITOPS_BRANCH=${gitopsBranch}",
                    "GITOPS_MANIFEST=${gitopsManifest}",
                    "RENDERED_MANIFEST=${manifest}",
                    "BUILD_IMAGE=${appimage}",
                    "BUILD_IMAGE_TAG=${apptag}"
                ]) {
                    withCredentials([gitUsernamePassword(credentialsId: 'gitops-credentials', gitToolName: 'Default')]) {
                        sh '''
                            set -eu
                            gitops_dir=$(mktemp -d .gitops-XXXXXX)
                            trap 'rm -rf -- "$gitops_dir"' EXIT

                            git -c http.sslVerify=true clone --depth 1 --branch "$GITOPS_BRANCH" --single-branch "$GITOPS_REPO" "$gitops_dir"
                            target="$gitops_dir/$GITOPS_MANIFEST"

                            if [ -f "$target" ]; then
                                published_image=$(awk '$1 == "image:" { gsub(/"/, "", $2); print $2; exit }' "$target")
                                published_tag=${published_image#"$BUILD_IMAGE:"}
                                case "$published_tag" in
                                    ''|*[!0-9]*) ;;
                                    *)
                                        if [ "$BUILD_IMAGE_TAG" -lt "$published_tag" ]; then
                                            echo "QA already has newer build $published_tag; skipping build $BUILD_IMAGE_TAG."
                                            exit 0
                                        fi
                                        ;;
                                esac
                            fi

                            mkdir -p "$(dirname "$target")"
                            cp "$RENDERED_MANIFEST" "$target"
                            git -C "$gitops_dir" add -- "$GITOPS_MANIFEST"
                            if git -C "$gitops_dir" diff --cached --quiet -- "$GITOPS_MANIFEST"; then
                                echo "QA manifest already matches build $BUILD_IMAGE_TAG."
                                exit 0
                            fi

                            git -C "$gitops_dir" -c user.name=Jenkins -c user.email=jenkins@users.noreply.github.com commit -m "Deploy $BUILD_IMAGE:$BUILD_IMAGE_TAG to QA"
                            git -C "$gitops_dir" -c http.sslVerify=true push origin "HEAD:refs/heads/$GITOPS_BRANCH"
                        '''
                    }
                }
            }
        }
    }
}
