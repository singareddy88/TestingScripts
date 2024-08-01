#!/bin/bash

# Variables
timestamp=$(date +%Y%m%d_%H%M%S)
output_dir="logs"
log_file="${output_dir}/ArgoCD Integration with Github_${timestamp}.log"
timestamp_file="${output_dir}/verification_timestamps.txt"
namespace="argocd"
application_name="my-application"
github_repo_url="https"
branch_or_tag="main"
manifest_path="path/to/manifests"
k8s_namespace="default"
max_retries=3
retry_delay=5

# Create the logs directory if it doesn't exist
mkdir -p "$output_dir"

# Function to log messages with timestamps
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$log_file"
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
log_message "Verifying the existence of ArgoCD application: $application_name"

# Check if the application exists
if ! retry "argocd app get \"$application_name\" &> /dev/null"; then
    log_message "Error: ArgoCD application '$application_name' does not exist."
    exit 1
else
    log_message "ArgoCD application '$application_name' exists."
fi

# Act
log_message "### Act ###"

# Verify connection from Repo URL to our GitHub Repository
log_message "Verifying connection to GitHub repository: $github_repo_url"
if ! retry "argocd app get \"$application_name\" -o json | jq -r '.spec.source.repoURL' | grep -q \"$github_repo_url\""; then
    log_message "Error: Repository URL does not match $github_repo_url"
    exit 1
else
    log_message "Success: Repository URL matches $github_repo_url"
fi

# Set the Revision to the branch or tag (e.g., main)
log_message "Setting application revision to branch or tag: $branch_or_tag"
if ! retry "argocd app set \"$application_name\" --revision \"$branch_or_tag\""; then
    log_message "Setting application revision failed."
    exit 1
fi

# Set the Path to the directory containing the manifests (if applicable)
log_message "Setting application path to manifests directory: $manifest_path"
if ! retry "argocd app set \"$application_name\" --path \"$manifest_path\""; then
    log_message "Setting application path failed."
    exit 1
fi

# Set the Namespace to the desired namespace in Kubernetes
log_message "Setting Kubernetes namespace to: $k8s_namespace"
if ! retry "argocd app set \"$application_name\" --dest-namespace \"$k8s_namespace\""; then
    log_message "Setting Kubernetes namespace failed."
    exit 1
fi

# Verify ArgoCD application is healthy with retry
log_message "Verifying ArgoCD application health status..."
app_health_status="argocd app get \"$application_name\" -o json | jq -r '.status.health.status'"
 
# Use retry function to get the health status and check if it's Healthy
app_health=$(retry "$app_health_status")
 
if [ "$app_health" == "Healthy" ]; then
    log_message "Success: ArgoCD application is healthy."
else
    log_message "Error: ArgoCD application is not healthy. Status: $app_health"
    exit 1
fi


# Verify ArgoCD application is in sync with GitHub
log_message "Verifying ArgoCD application sync status..."
app_sync_status_ArgoCD=$(argocd app get "$application_name" -o json | jq -r '.status.sync.status')
app_sync_status=$(retry "$app_sync_status_ArgoCD")
if [ "$app_sync_status" == "Synced" ]; then
    log_message "Success: ArgoCD application is in sync with GitHub."
else
    log_message "Error: ArgoCD application is not in sync. Status: $app_sync_status"
    exit 1
fi

# Verify the linkage between ArgoCD and GitHub repo
log_message "Verifying linkage between ArgoCD and GitHub repository..."
if ! retry "argocd app get \"$application_name\" -o json | jq -r '.spec.source.repoURL' | grep -q \"$github_repo_url\""; then
    log_message "Error: ArgoCD linkage to GitHub repository is incorrect."
    exit 1
else
    log_message "Success: ArgoCD is linked to GitHub repository $github_repo_url."
fi

# Save the timestamp of the last verification
echo "$timestamp" > "$timestamp_file"

log_message "Verification completed. Logs saved to $log_file."
