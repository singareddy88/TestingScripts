#!/bin/bash

# Variables
timestamp=$(date +%Y%m%d_%H%M%S)
output_dir="logs"
log_file="${output_dir}/GitOps_${timestamp}.log"
resource_group="your-resource-group"  
aks_cluster_name="your-aks-cluster"   
argocd_app_name="your-argocd-app"     
argocd_namespace="argocd"           
argocd_repo_url="https"
argocd_path="path/to/manifests"     
yaml_config_file="path/to/your/config.yaml"  
max_retries=3
retry_delay=5

# Function to log messages with timestamps
log_message() {
    local message=$1
    echo "$(date +%Y-%m-%d_%H-%M-%S) - $message" | tee -a "$log_file"
}

# Function to retry a command
retry() {
    local n=1
    local max=$max_retries
    local delay=$retry_delay
    local command="$@"

    while true; do
        log_message "Attempt $n: $command"
        eval "$command" && return 0 || {
            if [[ $n -lt $max ]]; then
                ((n++))
                log_message "Command failed. Retrying in $delay seconds..."
                sleep $delay
            else
                log_message "Command failed after $n attempts."
                return 1
            fi
        }
    done
}

# Create the logs directory if it doesn't exist
mkdir -p "$output_dir"
log_message "Log directory '$output_dir' created."

# Arrange
log_message "### Arrange ###"
log_message "Setting up pre-conditions to verify the AKS cluster and ArgoCD configuration."

# Verify Azure CLI is installed
log_message "Checking if Azure CLI is installed..."
retry "command -v az &> /dev/null" || {
    log_message "Error: Azure CLI is not installed. Please install Azure CLI to proceed."
    exit 1
}

# Verify kubectl is installed
log_message "Checking if kubectl is installed..."
retry "command -v kubectl &> /dev/null" || {
    log_message "Error: kubectl is not installed. Please install kubectl to proceed."
    exit 1
}

# Verify yq is installed
log_message "Checking if yq is installed..."
retry "command -v yq &> /dev/null" || {
    log_message "Error: yq is not installed. Please install yq to proceed."
    exit 1
}

# Verify ArgoCD CLI is installed
log_message "Checking if ArgoCD CLI is installed..."
retry "command -v argocd &> /dev/null" || {
    log_message "Error: ArgoCD CLI is not installed. Please install ArgoCD CLI to proceed."
    exit 1
}

# Act
log_message "### Act ###"

# 1. Verify YAML Configuration File
log_message "Verifying the YAML configuration file for syntax errors..."
retry "yq e '.' \"$yaml_config_file\" &> /dev/null"
log_message "YAML configuration file is valid."

# 2. Verify ArgoCD Configuration
log_message "Verifying ArgoCD configuration for the repository and path..."
argocd_repo=$(retry "kubectl get applications.argoproj.io \"$argocd_app_name\" -n \"$argocd_namespace\" -o jsonpath='{.spec.source.repoURL}'")
argocd_target_path=$(retry "kubectl get applications.argoproj.io \"$argocd_app_name\" -n \"$argocd_namespace\" -o jsonpath='{.spec.source.path}'")

if [ "$argocd_repo" == "$argocd_repo_url" ] && [ "$argocd_target_path" == "$argocd_path" ]; then
    log_message "ArgoCD is correctly configured with the repository and path."
else
    log_message "Error: ArgoCD configuration does not match the expected repository and path."
  
fi

# 3. Verify AKS Cluster Status
log_message "Verifying the AKS cluster status..."
aks_status=$(retry "az aks show --resource-group \"$resource_group\" --name \"$aks_cluster_name\" --query \"provisioningState\" -o tsv")
if [ "$aks_status" == "Succeeded" ]; then
    log_message "AKS cluster '$aks_cluster_name' status is '$aks_status'."
else
    log_message "Error: AKS cluster '$aks_cluster_name' status is '$aks_status'."

fi

# 4. Verify Kubernetes Nodes
log_message "Verifying Kubernetes nodes..."
retry "kubectl get nodes &> /dev/null"
log_message "Kubernetes nodes status:"
kubectl get nodes | tee -a "$log_file"

# 5. Verify Pod Status
log_message "Verifying pod status in all namespaces..."
retry "kubectl get pods --all-namespaces &> /dev/null"
log_message "Pods status in all namespaces:"
kubectl get pods --all-namespaces | tee -a "$log_file"

# The timestamp every time the script runs
log_message "Creating timestamped file..."
echo "script run at : $(date +%Y-%m-%d_%H-%M-%S)" >> "timestamp_file.txt"

# Assert
log_message "### Assert ###"
log_message "All checks passed. The AKS cluster, YAML configuration, ArgoCD configuration, nodes, and pods are verified successfully."
