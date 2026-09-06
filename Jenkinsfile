def appname = "flask-aws-monitor"[cite: 2]
def repo = "noamyonassi"  // Replace with your DockerHub username
def appimage = "${repo}/${appname}"[cite: 2]
def apptag = "${env.BUILD_NUMBER}"[cite: 2]

podTemplate(containers: [
      containerTemplate(name: 'jnlp', image: 'jenkins/inbound-agent', ttyEnabled: true)[cite: 2],
      // שים לב: הסרתי את command: 'cat' כדי שה-Daemon של Docker יעלה בצורה תקינה ברקע
      containerTemplate(name: 'docker', image: 'docker:dind', ttyEnabled: true, privileged: true)
  ])
  {
    node(POD_LABEL) {
        // תיקנתי את שגיאת הכתיב ל-checkout
        stage('checkout') {
            container('jnlp') {
              sh '/usr/bin/git config --global http.sslVerify false'[cite: 2]
              checkout scm[cite: 2]
            }
        } // end checkout

        stage('build') {
            container('docker') {
              echo "Waiting for Docker daemon to start..."
              sleep 5 // השהייה קצרה כדי לתת לשרת ה-Docker זמן לעלות
              
              echo "Building docker image..."[cite: 2]
              // בניית התמונה ותיוגה עם מספר ה-Build
              sh "docker build -t ${appimage}:${apptag} ."
              // תיוג נוסף כ-latest למען הנוחות
              sh "docker tag ${appimage}:${apptag} ${appimage}:latest"
            }
        } //end build

        stage('push') {
            container('docker') {
              echo "Pushing docker image to DockerHub..."
              // שימוש ב-Credentials של Jenkins לאימות מול DockerHub בצורה מאובטחת
              withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME')]) {
                  sh "echo \$DOCKER_PASSWORD | docker login -u \$DOCKER_USERNAME --password-stdin"
                  // דחיפת שתי התגיות ל-DockerHub
                  sh "docker push ${appimage}:${apptag}"
                  sh "docker push ${appimage}:latest"
              }
            }
        } //end push
    }
}
