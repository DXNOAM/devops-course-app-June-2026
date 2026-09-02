@Library('my-shared-library') _ //[cite: 5]

pipeline {
    agent any //[cite: 5]

    environment {
        APP_NAME = 'my-flask-app' //[cite: 5]
        APP_ENV = 'production' //[cite: 5]
        // IF APP_DEBUG is set to 'true' the DEBUG_BRANCH will be used as we might run it using pipeline script without full git repo
        APP_DEBUG = 'true' //[cite: 5]
        DEBUG_BRANCH = 'develop' //[cite: 5]
    }

    stages {
        stage('Build') { //[cite: 5]
            steps {
                script {
                    // 
                    myLibrary.buildApp(env.APP_NAME) //[cite: 5]
                }
            }
        }
        
        // Check
        stage('Parallel Tests') { //[cite: 5]
            failFast true //[cite: 5]
            parallel {
                stage('Unit Tests') { //[cite: 5]
                    steps {
                        echo 'Running Unit Tests...' //[cite: 5]
                    }
                }
                stage('Security & Linting') { //[cite: 5]
                    steps {
                        script {
                            echo 'Running Code Analysis and Security Scans with SonarQube...'
                            
                            // codeQuality.groovy Shared Library
                            codeQuality.sonarCreateProject(env.JOB_NAME)
                            codeQuality.sonarLocalScan()
                        }
                    }
                }
            }
        }
        
        // Deploy
        stage('Deploy') { //[cite: 5]
            steps {
                script {
                    // If APP_DEBUG is set to 'true' set env.BRANCH_NAME to DEBUG_BRANCH
                    env.BRANCH_NAME = env.APP_DEBUG == 'true' ? env.DEBUG_BRANCH : env.BRANCH_NAME //[cite: 5]
                    // Call the deployApp function with the branch name, app name, and build number
                    myLibrary.deployApp(env.BRANCH_NAME, env.APP_NAME, env.BUILD_NUMBER) //[cite: 5]
                }
            }
        }
    }

    post { //[cite: 5]
        always { //[cite: 5]
            script {
                // Call the cleanup function
                myLibrary.cleanup() //[cite: 5]
            }
        }
    }
}
