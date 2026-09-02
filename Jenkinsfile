@Library('my-shared-library') _ //[cite: 2]

pipeline {
    agent any //[cite: 1, 2]

    environment {
        APP_NAME = 'my-flask-app' //
        APP_ENV = 'production' //[cite: 2]
        // IF APP_DEBUG is set to 'true' the DEBUG_BRANCH will be used as we might run it using pipeline script without full git repo
        APP_DEBUG = 'true' //[cite: 2]
        DEBUG_BRANCH = 'develop' //[cite: 2]
    }

    stages {
        stage('Build') { //[cite: 1, 2]
            steps {
                script {
                    // קריאה לפונקציית הבנייה תוך העברת שם האפליקציה
                    myLibrary.buildApp(env.APP_NAME) //[cite: 2]
                }
            }
        }
        
        // Check
        stage('Parallel Tests') { //[cite: 1]
            failFast true //[cite: 1]
            parallel {
                stage('Unit Tests') { //[cite: 1]
                    steps {
                        echo 'Running Unit Tests...' //[cite: 1]
                    }
                }
                stage('Security & Linting') { //[cite: 1]
                    steps {
                        echo 'Running Code Analysis and Security Scans...' //[cite: 1]
                    }
                }
            }
        }
        
        // Deploy
        stage('Deploy') { //[cite: 1, 2]
            steps {
                script {
                    // If APP_DEBUG is set to 'true' set env.BRANCH_NAME to DEBUG_BRANCH
                    env.BRANCH_NAME = env.APP_DEBUG == 'true' ? env.DEBUG_BRANCH : env.BRANCH_NAME //[cite: 2]
                    // Call the deployApp function with the branch name, app name, and build number
                    myLibrary.deployApp(env.BRANCH_NAME, env.APP_NAME, env.BUILD_NUMBER) //[cite: 2]
                }
            }
        }
    }

    post { //[cite: 2]
        always { //[cite: 2]
            script {
                // Call the cleanup function
                myLibrary.cleanup() //[cite: 2]
            }
        }
    }
}
