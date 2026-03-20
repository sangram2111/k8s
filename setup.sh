#!/bin/bash
set -e

echo "=== Deploying Jenkins to Kubernetes ==="
kubectl apply -f k8s/jenkins-rbac.yaml
kubectl apply -f k8s/jenkins-deployment.yaml
kubectl apply -f k8s/jenkins-service.yaml

echo ""
echo "=== Waiting for Jenkins pod to be ready ==="
kubectl rollout status deployment/jenkins -n jenkins

echo ""
echo "=== Jenkins Initial Admin Password ==="
JENKINS_POD=$(kubectl get pod -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
echo "Run this command once the pod is fully up:"
echo "  kubectl exec -n jenkins $JENKINS_POD -- cat /var/jenkins_home/secrets/initialAdminPassword"

echo ""
echo "=== Access Jenkins ==="
echo "  NodePort:  http://<node-ip>:32000"
echo "  Minikube:  minikube service jenkins -n jenkins --url"

echo ""
echo "=== Deploying Abstergo Website Service ==="
kubectl apply -f k8s/service.yaml

echo ""
echo "Done! Configure Jenkins pipeline to complete CI/CD setup."
