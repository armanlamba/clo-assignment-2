# Kubernetes Cluster and Application Deployment

This README provides step-by-step instructions for setting up the infrastructure using Terraform, deploying a containerized web application and MySQL database on a Kubernetes cluster using `kind`, and exposing them with appropriate service types.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Infrastructure Setup with Terraform](#infrastructure-setup-with-terraform)
- [Cluster Setup](#cluster-setup)
- [Namespace and Secret Creation](#namespace-and-secret-creation)
- [Application Deployment](#application-deployment)
- [Service Exposure](#service-exposure)
- [Updating the Application](#updating-the-application)
- [Service Types Explanation](#service-types-explanation)

## Prerequisites

Ensure the following tools are installed:
- Docker
- kubectl
- kind
- AWS CLI (for ECR access)
- Terraform

## Infrastructure Setup with Terraform

1. Navigate to the directory containing your Terraform configuration files:
    ```bash
    cd terraform
    ```

2. Initialize the Terraform working directory:
    ```bash
    terraform init
    ```

3. Apply the Terraform configuration to create an Amazon EC2 instance for the Kubernetes cluster:
    ```bash
    terraform apply -auto-approve
    ```

## Cluster Setup

1. SSH into the EC2 instance created by Terraform (use the public IP or DNS provided in the Terraform output).

2. Clone the repository:
    ```bash
    cd clo
    ```

3. Switch to the development branch:
    ```bash
    git switch dev
    ```

4. Create a Kubernetes cluster using `kind`:
    ```bash
    kind create cluster --config kind-config.yaml
    ```

5. Apply namespace configuration:
    ```bash
    kubectl apply -f namespaces.yaml
    ```

## Namespace and Secret Creation

1. Create Docker registry secrets for each namespace:
    ```bash
   add your secrets 
    ```

2. Create MySQL-specific secrets:
    ```bash
    add your secrets
    ```

## Application Deployment

1. Deploy MySQL and web application components:
    ```bash
    kubectl apply -f mysql-pod.yaml -n mysql
    kubectl apply -f mysql-service.yaml -n mysql
    kubectl apply -f webapp-pod.yaml -n webapp
    kubectl apply -f webapp-service.yaml -n webapp
    ```

2. Verify the deployment:
    ```bash
    kubectl get pods -n webapp
    ```

3. Check cluster info and exposed services:
    ```bash
    kubectl cluster-info
    ```

## Service Exposure

1. Access the web application:
    ```bash
    curl localhost:30000
    ```

    Alternatively, view in a browser at:
    ```plaintext
    http://<EC2-public-IP>:30000/
    ```

2. To monitor logs:
    ```bash
    kubectl logs -f webapp-pod -n webapp
    ```

## Updating the Application

1. Pull, tag, and push the updated image:
    ```bash
    docker pull 289052325869.dkr.ecr.us-east-1.amazonaws.com/assignment2-dev-ecr:my_app
    docker tag 289052325869.dkr.ecr.us-east-1.amazonaws.com/assignment2-dev-ecr:my_app 289052325869.dkr.ecr.us-east-1.amazonaws.com/assignment2-dev-ecr:my_app-v2
    docker push 289052325869.dkr.ecr.us-east-1.amazonaws.com/assignment2-dev-ecr:my_app-v2
    ```

2. Update the deployment manifest (`webapp-deployment.yaml` and `mysql-deployment.yaml`) to use the new image version.

3. Apply the updated deployment:
    ```bash
    kubectl apply -f webapp-deployment.yaml -n webapp
    kubectl rollout status deployment/webapp-deployment -n webapp
    ```

## Service Types Explanation

- **Web Application (NodePort)**: The web app uses a `NodePort` service, enabling external access to the application from a specified port.
- **MySQL Application (ClusterIP)**: The MySQL application uses a `ClusterIP` service, allowing only internal access within the cluster for security purposes.

This setup ensures secure internal communication for the database, while the web application is accessible externally.
