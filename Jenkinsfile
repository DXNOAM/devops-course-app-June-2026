pipeline {
    agent any

    // 1. הגדרת משתני סביבה - שימוש ב-ENV עבור שם האפליקציה
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
        
        // שלב הבדיקות שונה כדי להריץ משימות במקביל
        stage('Parallel Tests') {
            // הוספת failFast מומלצת: אם בדיקה אחת נכשלת, הכל נעצר כדי לחסוך משאבים
            failFast true 
            parallel {
                stage('Unit Tests') {
                    steps {
                        echo 'Running Unit Tests...'
                        // פקודות עבור Unit Tests (למשל pytest)
                    }
                }
                stage('Security & Linting') {
                    steps {
                        echo 'Running Code Analysis and Security Scans...'
                        // פקודות עבור סריקות קוד (למשל flake8 או סריקות אבטחה)
                    }
                }
            }
        }
        
        // החלפנו את התוכן של שלב ה-Deploy כדי שיבצע את ההעלאה בפועל
        stage('Deploy') {
            steps {
                echo 'Deploying to Docker Hub...'
                
                // 4. שימוש ב-Jenkins Credentials שהגדרת כדי לאפשר גישה בטוחה
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    
                    // התחברות מאובטחת ל-Docker Hub באמצעות המשתנים מההרשאה
                    sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                    
                    // 2+3. בניית ה-Image עם שם האפליקציה ומספר הבילד הנוכחי בתור תג
                    sh "docker build -t ${DOCKER_USER}/${env.APP_NAME}:${env.BUILD_NUMBER} ."
                    
                    // העלאת ה-Image ל-Docker Hub
                    sh "docker push ${DOCKER_USER}/${env.APP_NAME}:${env.BUILD_NUMBER}"
                }
            }
        }
    }
}
