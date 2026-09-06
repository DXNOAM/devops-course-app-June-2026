def appname = "flask-aws-monitor"
def repo = "noamyonassi"
def appimage = "${repo}/${appname}"
def apptag = "${env.BUILD_NUMBER}"

podTemplate(containers: [
      containerTemplate(name: 'jnlp', image: 'jenkins/inbound-agent', ttyEnabled: true),
      containerTemplate(name: 'docker', image: 'docker:dind', ttyEnabled: true, privileged: true),
      containerTemplate(name: 'trivy', image: 'aquasec/trivy:latest', command: 'cat', ttyEnabled: true)
  ])
  {
    node(POD_LABEL) {
        stage('checkout') {
            container('jnlp') {
              sh '/usr/bin/git config --global http.sslVerify false'
              checkout scm
            }
        } // end checkout

        // Scan & build
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
                        
                        //Save Image
                        echo "Saving image to tarball for scanning..."
                        sh "docker save -o image.tar ${appimage}:${apptag}"
                    }
                }
            }
        ) // end parallel

        // another scan
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
    }
}
