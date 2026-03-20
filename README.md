# Abstergo Corp — CI/CD Pipeline with Jenkins & Kubernetes

Automated CI/CD pipeline that builds, containerizes, and deploys the Abstergo online shopping portal to a Kubernetes cluster on every code push.

## Architecture

```
GitHub Push → Jenkins (on K8s) → Docker Build → DockerHub Push → Kubernetes Deploy
```

## Project Structure

```
├── Dockerfile                  # Builds Nginx image with website content
├── Jenkinsfile                 # CI/CD pipeline definition
├── setup.sh                    # One-command setup script
├── website/
│   └── index.html              # Production website
└── k8s/
    ├── jenkins-rbac.yaml       # Jenkins namespace, ServiceAccount & RBAC
    ├── jenkins-deployment.yaml # Jenkins Deployment (with Docker socket)
    ├── jenkins-service.yaml    # Jenkins NodePort Service (port 32000)
    ├── deployment.yaml         # Website Deployment (2 replicas, rolling update)
    └── service.yaml            # Website NodePort Service (port 30080)
```

## Prerequisites

- Kubernetes cluster (Minikube / EKS / kubeadm)
- kubectl configured to access the cluster
- DockerHub account
- GitHub account with a repository for this project

---

## Step 1 — Deploy Jenkins & Website Service to Kubernetes

```bash
./setup.sh
```

This creates the Jenkins namespace, RBAC, deployment, service, and the website service on your cluster.

---

## Step 2 — Get Jenkins Admin Password

```bash
kubectl exec -n jenkins $(kubectl get pod -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- cat /var/jenkins_home/secrets/initialAdminPassword
```

Copy the password printed in the terminal. You will need it in the next step.

---

## Step 3 — Access Jenkins UI

Find your node IP:

```bash
kubectl get nodes -o wide
```

Open a browser and go to:

```
http://<node-ip>:32000
```

For Minikube users:

```bash
minikube service jenkins -n jenkins --url
```

---

## Step 4 — Unlock Jenkins

1. On the **Unlock Jenkins** page, paste the admin password from Step 2
2. Click **Continue**

---

## Step 5 — Install Plugins

1. On the **Customize Jenkins** page, click **Install suggested plugins**
2. Wait for all plugins to install
3. After installation, go to **Manage Jenkins → Plugins → Available plugins**
4. Search and install these additional plugins:
   - **Docker Pipeline**
   - **Credentials Binding**
5. Restart Jenkins if prompted

---

## Step 6 — Create Admin User

1. Fill in the **Create First Admin User** form (username, password, full name, email)
2. Click **Save and Continue**
3. On the **Instance Configuration** page, keep the default Jenkins URL and click **Save and Finish**
4. Click **Start using Jenkins**

---

## Step 7 — Add DockerHub Credentials

1. Go to **Manage Jenkins → Credentials**
2. Click **(global)** under **Stores scoped to Jenkins**
3. Click **Add Credentials**
4. Fill in:
   - **Kind:** Username with password
   - **Username:** your DockerHub username
   - **Password:** your DockerHub password or access token
   - **ID:** `dockerhub-creds`
   - **Description:** DockerHub
5. Click **Create**

---

## Step 8 — Push Project to GitHub

If not already done, push this project to a GitHub repository:

```bash
cd Kubernetes_project
git init
git add .
git commit -m "Initial commit - Abstergo CI/CD pipeline"
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

---

## Step 9 — Update Jenkinsfile

Edit `Jenkinsfile` and replace the placeholder values:

1. Set `DOCKER_HUB_USER` to your actual DockerHub username
2. Set the Git repo URL in the Clone stage to your GitHub repo URL

```groovy
environment {
    DOCKER_HUB_USER = 'your-actual-dockerhub-username'
}
// ...
git branch: 'main', url: 'https://github.com/<your-username>/<your-repo>.git'
```

Commit and push the changes:

```bash
git add Jenkinsfile
git commit -m "Update Jenkinsfile with DockerHub and repo details"
git push
```

---

## Step 10 — Create Jenkins Pipeline Job

1. On the Jenkins dashboard, click **New Item**
2. Enter name: `abstergo-website`
3. Select **Pipeline**, then click **OK**
4. Under **Build Triggers**, check **GitHub hook trigger for GITScm polling**
5. Under **Pipeline**:
   - **Definition:** select **Pipeline script from SCM**
   - **SCM:** Git
   - **Repository URL:** `https://github.com/<your-username>/<your-repo>.git`
   - **Branch Specifier:** `*/main`
   - **Script Path:** `Jenkinsfile`
6. Click **Save**

---

## Step 11 — Configure GitHub Webhook

1. Go to your GitHub repository → **Settings → Webhooks → Add webhook**
2. Fill in:
   - **Payload URL:** `http://<node-ip>:32000/github-webhook/`
   - **Content type:** `application/json`
   - **Which events:** select **Just the push event**
3. Click **Add webhook**

> **Note:** The Jenkins URL must be publicly reachable for GitHub webhooks to work. If running locally, you can use [ngrok](https://ngrok.com) to expose Jenkins, or trigger builds manually.

---

## Step 12 — Trigger the First Build

**Option A — Automatic:** Push any code change to the `main` branch. The webhook triggers the pipeline.

**Option B — Manual:** In Jenkins, open the `abstergo-website` job and click **Build Now**.

---

## Step 13 — Access the Deployed Website

After a successful build, the website is live:

```bash
# Find node IP
kubectl get nodes -o wide

# Access website
http://<node-ip>:30080
```

For Minikube:

```bash
minikube service abstergo-website --url
```

---

## How It Works

1. Developers push code to the `main` branch on GitHub
2. GitHub webhook triggers the Jenkins pipeline
3. Jenkins builds a Docker image tagged with the build number
4. Image is pushed to DockerHub
5. Kubernetes deployment is updated with the new image tag
6. Rolling update ensures zero-downtime deployment
