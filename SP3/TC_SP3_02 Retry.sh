#!/bin/bash

# Variables
timestamp=$(date +%Y%m%d_%H%M%S)
output_dir="logs"
log_file="${output_dir}/Bootstrap Cluster_${timestamp}.log"
bootstrap_namespace="capi-system"
azure_namespace="capz-system"
helm_namespace="helm-system"
cert_manager_namespace="cert-manager"
required_vars=("AZURE_SUBSCRIPTION_ID" "AZURE_TENANT_ID" "AZURE_CLIENT_ID" "AZURE_CLIENT_SECRET")
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

# Arrange: Verify SSH access to the VM
log_message "### Arrange ###"
log_message "Verifying SSH access to the VM..."
if ! retry "ssh -o BatchMode=yes -o ConnectTimeout=5 user@localhost exit"; then
    log_message "SSH verification failed."
fi

# Act: Verify Bootstrap Cluster
log_message "### Act ###"
log_message "Verifying bootstrap cluster is up and running..."
if ! retry "kubectl get pods -n $bootstrap_namespace --no-headers | grep 'bootstrap'"; then
    log_message "Bootstrap cluster verification failed."
fi

# Function to verify if an environment variable is set
verify_env_var() {
    local var=$1
    if [ -z "${!var}" ]; then
        log_message "Error: Environment variable '$var' is not set."
        return 1
    else
        log_message "Environment variable '$var' is set."
        return 0
    fi
}
 
# Verify Environment Variables
log_message "Verifying environment variables are set as expected..."

for var in "${required_vars[@]}"; do
    retry "verify_env_var '$var'"
done


# Verify CAPI Installation
log_message "Verifying CAPI is installed..."
if ! retry "clusterctl version"; then
    log_message "CAPI installation verification failed."
fi

# Verify CAPZ Installation
log_message "Verifying CAPZ installation..."
if ! retry "kubectl get pods -n $azure_namespace --no-headers | grep 'capz-controller-manager'"; then
    log_message "CAPZ installation verification failed."
fi

# Verify Pod Status of Azure Provider
log_message "Verifying pod status of Azure provider..."
if ! retry "kubectl get pods -n $azure_namespace --no-headers | grep 'Running'"; then
    log_message "Azure provider pod status verification failed."
fi

# Verify Pod Status of Bootstrap Provider
log_message "Verifying pod status of bootstrap provider..."
if ! retry "kubectl get pods -n $bootstrap_namespace --no-headers | grep 'Running'"; then
    log_message "Bootstrap provider pod status verification failed."
fi

# Verify Pod Status of Helm Add-on Provider
log_message "Verifying pod status of Helm add-on provider..."
if ! retry "kubectl get pods -n $helm_namespace --no-headers | grep 'Running'"; then
    log_message "Helm add-on provider pod status verification failed."
fi

# Verify Cert Manager is Up and Running
log_message "Verifying cert manager is up and running..."
if ! retry "kubectl get pods -n $cert_manager_namespace --no-headers | grep 'Running'"; then
    log_message "Cert manager verification failed."
fi

# Verify Certificates are Getting Created
log_message "Verifying certificates are getting created..."
if ! retry "kubectl get certificates -n $cert_manager_namespace --no-headers"; then
    log_message "Certificate creation verification failed."
fi

# Verify Cluster Identity Secret is Created
log_message "Verifying cluster identity secret is created..."
if ! retry "kubectl get secret cluster-identity-secret -n $azure_namespace"; then
    log_message "Cluster identity secret verification failed."
fi

# Save the timestamp of the last verification
echo "$timestamp" > "$timestamp_file"

log_message "Verification completed. Logs saved to $log_file."
