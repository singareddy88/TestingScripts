#!/bin/bash

# Variables
timestamp=$(date +%y%m%d_%H%M%S)
output_dir="logs"
log_file="${output_dir}/ArgoCD_verification_${timestamp}.log"
namespace="argocd"
helm_repo_name="helm_charts"
git_repo_name="helm"
app_yaml_path="/path/to/your/App.yaml"
max_retries=3
retry_delay=5

# Create the logs directory if it doesn't exist
mkdir -p "$output_dir"
log_message "Log directory '$output_dir' created."

# Function to log messages with timestamps
log_message() {
    local message=$1
    echo "$(date +%y-%m-%d_%H:%M:%S) - $message" | tee -a "$log_file"
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

# Arrange
log_message "### Arrange ###"
log_message "Starting ArgoCD verification process."

# Function to verify ArgoCD deployment
verify_argocd_deployment() {
    log_message "Checking if ArgoCD is deployed in namespace..."
    retry "kubectl get deployment -n \"$namespace\" | grep 'argocd_service'"

    log_message "Checking if all ArgoCD pods are running..."
    retry "argo_pods_status=\$(kubectl get pods -n \"$namespace\" -o jsonpath='{.items[*].status.phase}' | grep -v Running)"
    if [ -z "$argo_pods_status" ]; then
        log_message "All ArgoCD pods are running."
    else
        log_message "Error: Some ArgoCD pods are not running: $argo_pods_status"
        exit 1
    fi

    # Verify that repositories are added to ArgoCD
    log_message "Verifying that the repositories are added to ArgoCD..."

    # Check for Helm Charts repository
    retry "argocd repo list | grep -q '$helm_repo_name'"
    log_message "Helm Charts repository '$helm_repo_name' is added to ArgoCD."

    # Check for Helm Git repository
    retry "argocd repo list | grep -q '$git_repo_name'"
    log_message "Helm Git repository '$git_repo_name' is added to ArgoCD."

    # Verify that the ArgoCD service has an external IP
    log_message "Checking ArgoCD service for external IP address..."
    external_ip=$(retry "kubectl get svc -n \"$namespace\" argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}'")
    if [ -z "$external_ip" ]; then
        log_message "Error: ArgoCD service does not have an external IP."
        exit 1
    else
        log_message "ArgoCD service external IP is: $external_ip"
    fi

    # Verify access to the ArgoCD server using the external IP
    log_message "Attempting to access ArgoCD server at $external_ip..."
    retry "curl -s 'http://$external_ip' &> /dev/null"
    log_message "Successfully accessed ArgoCD server at $external_ip."
}

# Call the verification function
verify_argocd_deployment

# Assert
log_message "### Assert ###"
log_message "Verifying configuration in App.yaml files..."

# Verify App.yaml configurations
if [ -f "$app_yaml_path" ]; then
    log_message "Found App.yaml at $app_yaml_path, checking configurations..."
    retry "grep -q 'key: value' '$app_yaml_path'"
    log_message "Configuration in App.yaml is as expected."
else
    log_message "Error: App.yaml not found at $app_yaml_path."
    exit 1
fi

# The timestamp every time the script runs
log_message "Creating timestamped file..."
echo "script run at : $(date +"%Y-%m-%d_%H-%M-%S")" >> "file_path"

log_message "ArgoCD verification completed successfully."
