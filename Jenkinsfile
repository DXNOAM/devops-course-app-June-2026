pipeline {
    agent any

    // ENV
    environment {
        APP_NAME = 'my-flask-app'
    }

    stages {
        stage('Build') {
            steps {
                echo "Building application: ${env.APP_NAME}..."
                // Build steps here
            }
        }
        
        // Check
        stage('Parallel Tests') {
            //
            failFast true 
            parallel {
                stage('Unit Tests') {
                    steps {
                        echo 'Running Unit Tests...'
                        //
                    }
                }
                stage('Security & Linting') {
                    steps {
                        echo 'Running Code Analysis and Security Scans...'
                        //
                    }
                }
            }
        }
        
        // Deploy
        stage('Deploy') {
            steps {
                echo 'Deploying to Docker Hub...'
                
                // 4. Jenkins Credentials
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    
                    // Login Docker Hub
                    sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                    
                    // Build Image For Docker Hub
                    sh "docker build -t ${DOCKER_USER}/${env.APP_NAME}:${env.BUILD_NUMBER} ."
                    
                    // Upload Image Docker Hub
                    sh "docker push ${DOCKER_USER}/${env.APP_NAME}:${env.BUILD_NUMBER}"
                }
            }
        }
    }
}
