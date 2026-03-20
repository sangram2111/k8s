pipeline {
    agent any

    environment {
        DOCKER_HUB_USER = 'your-dockerhub-username'   // Replace with actual DockerHub username
        IMAGE_NAME      = 'abstergo-website'
        IMAGE_TAG       = "${BUILD_NUMBER}"
    }

    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/<your-org>/Kubernetes_project.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:latest ."
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${DOCKER_HUB_USER}/${IMAGE_NAME}:latest
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh """
                    sed -i 's|DOCKER_HUB_USER|${DOCKER_HUB_USER}|g' k8s/deployment.yaml
                    sed -i 's|:latest|:${IMAGE_TAG}|g' k8s/deployment.yaml
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml
                    kubectl rollout status deployment/abstergo-website
                """
            }
        }
    }

    post {
        success { echo 'Pipeline completed successfully — website deployed!' }
        failure { echo 'Pipeline failed. Check logs for details.' }
    }
}
