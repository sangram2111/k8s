pipeline {
    agent any

    environment {
        DOCKER_HUB_USER = 'sangram2111'
        IMAGE_NAME      = 'abstergo-website'
        IMAGE_TAG       = "${BUILD_NUMBER}"
    }

    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/sangram2111/k8s.git'
            }
        }

        stage('Build & Push with Kaniko') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        # Create Kaniko docker config for DockerHub auth
                        DOCKER_AUTH=$(echo -n "$DOCKER_USER:$DOCKER_PASS" | base64)
                        cat > /tmp/kaniko-config.json <<EOF
{"auths":{"https://index.docker.io/v1/":{"auth":"${DOCKER_AUTH}"}}}
EOF

                        # Create Kaniko pod manifest
                        cat > /tmp/kaniko-pod.yaml <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: kaniko-${BUILD_NUMBER}
  namespace: jenkins
spec:
  containers:
    - name: kaniko
      image: gcr.io/kaniko-project/executor:latest
      args:
        - "--dockerfile=Dockerfile"
        - "--context=git://github.com/sangram2111/k8s.git#refs/heads/main"
        - "--destination=${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
        - "--destination=${DOCKER_HUB_USER}/${IMAGE_NAME}:latest"
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker
  restartPolicy: Never
  volumes:
    - name: docker-config
      secret:
        secretName: kaniko-docker-creds
YAML

                        # Create K8s secret with DockerHub credentials
                        kubectl delete secret kaniko-docker-creds -n jenkins --ignore-not-found
                        kubectl create secret generic kaniko-docker-creds -n jenkins \
                            --from-file=config.json=/tmp/kaniko-config.json

                        # Delete old Kaniko pod if exists
                        kubectl delete pod kaniko-${BUILD_NUMBER} -n jenkins --ignore-not-found

                        # Launch Kaniko pod
                        kubectl apply -f /tmp/kaniko-pod.yaml

                        # Wait for Kaniko to complete
                        echo "Waiting for Kaniko build to complete..."
                        kubectl wait --for=condition=Ready pod/kaniko-${BUILD_NUMBER} -n jenkins --timeout=30s 2>/dev/null || true
                        kubectl logs -f kaniko-${BUILD_NUMBER} -n jenkins

                        # Wait for pod to finish
                        while true; do
                            PHASE=$(kubectl get pod kaniko-${BUILD_NUMBER} -n jenkins -o jsonpath='{.status.phase}')
                            if [ "$PHASE" = "Succeeded" ] || [ "$PHASE" = "Failed" ]; then
                                break
                            fi
                            sleep 2
                        done
                        kubectl delete pod kaniko-${BUILD_NUMBER} -n jenkins --ignore-not-found
                        rm -f /tmp/kaniko-config.json /tmp/kaniko-pod.yaml

                        if [ "$PHASE" != "Succeeded" ]; then
                            echo "Kaniko build failed with phase: $PHASE"
                            exit 1
                        fi
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                        # Create image pull secret in default namespace
                        kubectl delete secret dockerhub-pull-secret -n default --ignore-not-found
                        kubectl create secret docker-registry dockerhub-pull-secret -n default \
                            --docker-server=https://index.docker.io/v1/ \
                            --docker-username=\$DOCKER_USER \
                            --docker-password=\$DOCKER_PASS

                        sed -i 's|DOCKER_HUB_USER|${DOCKER_HUB_USER}|g' k8s/deployment.yaml
                        sed -i 's|:latest|:${IMAGE_TAG}|g' k8s/deployment.yaml
                        kubectl apply -f k8s/deployment.yaml
                        kubectl apply -f k8s/service.yaml || true
                        kubectl rollout status deployment/abstergo-website -n default
                    """
                }
            }
        }
    }

    post {
        success { echo 'Pipeline completed successfully — website deployed!' }
        failure { echo 'Pipeline failed. Check logs for details.' }
    }
}
