def appname = "flask-aws-monitor"
def repo = "noamyonassi"  // Replace with your DockerHub username
def appimage = "${repo}/${appname}"
def apptag = "${env.BUILD_NUMBER}"

podTemplate(containers: [
      containerTemplate(name: 'jnlp', image: 'jenkins/inbound-agent', ttyEnabled: true),
      containerTemplate(name: 'docker', image: 'docker:dind', ttyEnabled: true, privileged: true)
  ])
  {
    node(POD_LABEL) {
        stage('checkout') {
            container('jnlp') {
              sh '/usr/bin/git config --global http.sslVerify false'
              checkout scm
            }
        }

        stage('build') {
            container('docker') {
              echo "Waiting for Docker daemon to start..."
              sleep 5
              
              echo "Building docker image..."
              sh "docker build -t ${appimage}:${apptag} ."
              sh "docker tag ${appimage}:${apptag} ${appimage}:latest"
            }
        }

        stage('push') {
            container('docker') {
              echo "Pushing docker image to DockerHub..."
              withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME')]) {
                  sh "echo \$DOCKER_PASSWORD | docker login -u \$DOCKER_USERNAME --password-stdin"
                  sh "docker push ${appimage}:${apptag}"
                  sh "docker push ${appimage}:latest"
              }
            }
        }
    }
}
