#!/bin/bash

# Variables
timestamp=$(date +%Y%m%d_%H%M%S)
output_dir="logs"
log_file="${output_dir}/Management Cluster_${timestamp}.log"
kubectl get kubeconfig "gze-mgmt-cluster-004"
KUBECONFIG_PATH="/root/.kube/config1"
# Saving kubeconfig file
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --file $KUBECONFIG_PATH
REPO_URL="https://github.com/kuldipmadnani/capiz-vmss-helm.git"
CUSTOM_IMAGE="your-custom-image"
VMSS_NAME="gze-mgmt-cluster-004-mp-0"
CAPZ_COMPONENTS=("azure-provider" "bootstrap-provider" "control-plane-provider" "helm-addon-provider")
expected_zones='["1","2","3"]'
CONTROL_PLANES=3
WORKER_NODES=3
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
log_message "VMSS Cluster"

# Verify kubeconfig path is set
log_message "Setting kubeconfig path..."
export KUBECONFIG="$KUBECONFIG_PATH"
log_message "KUBECONFIG set to $KUBECONFIG_PATH."

# Act
log_message "### Act ###"

# 1. Verify kubeconfig and management cluster connection
log_message "Verifying kubeconfig and management cluster connection..."
if ! retry "pwd"; then
    log_message "pwd path"
fi


# 1. Verify kubeconfig and management cluster connection
log_message "Verifying kubeconfig and management cluster connection..."
if ! retry "kubectl --kubeconfig=$KUBECONFIG_PATH cluster-info"; then
    log_message "Failed to connect to the management cluster."
fi

# 2. Verify the necessary helm chart and values in GitHub repository
log_message "Verifying the necessary helm chart and values in GitHub repository..."
if ! retry "git ls-remote \"$REPO_URL\" > /dev/null 2>&1"; then
    log_message "Error: Unable to access the GitHub repository."
   else
    log_message "Helm chart and values are present in the GitHub repository."
fi

# 3. Verify if cert-manager is deployed and healthy
log_message "Verifying if cert-manager is deployed and healthy..."
if ! retry "kubectl --kubeconfig=$KUBECONFIG_PATH get pods --namespace cert-manager | grep cert-manager > /dev/null 2>&1"; then
    log_message "Error: cert-manager is not deployed."
 else
    log_message "cert-manager is deployed."
fi

# 4. Verify if Calico plugin is installed
log_message "Verifying if Calico plugin is installed..."
if ! retry "kubectl --kubeconfig=$KUBECONFIG_PATH get pods --namespace kube-system | grep calico > /dev/null 2>&1"; then
    log_message "Error: Calico plugin is not installed."
else
    log_message "Calico plugin is installed."
fi

# 5. Verify custom image usage
log_message "Verifying custom image usage..."
if ! retry "az vmss show --name \"$VMSS_NAME\" --query \"virtualMachineProfile.storageProfile.imageReference.id\" | grep \"$CUSTOM_IMAGE\" > /dev/null 2>&1"; then
    log_message "Error: Custom image is not being used."
   else
    log_message "Custom image is being used."
fi

# 6. Verify 3 control planes & 3 worker nodes are up and running
# Get kubeconfig
retry "kubectl get kubeconfig 'gze-mgmt-cluster-004'"
 
# Saving kubeconfig file
retry "az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --file $KUBECONFIG_PATH"

log_message "Verifying 3 control planes & 3 worker nodes are up and running..."
retry "current_control_planes=\$(kubectl --kubeconfig=$KUBECONFIG_PATH get nodes --selector='node-role.kubernetes.io/control-plane' --no-headers | wc -l)"
retry "current_worker_nodes=\$(kubectl --kubeconfig=$KUBECONFIG_PATH get nodes --selector='!node-role.kubernetes.io/control-plane' --no-headers | wc -l)"
 
if [ "$current_control_planes" -eq "$CONTROL_PLANES" ] && [ "$current_worker_nodes" -eq "$WORKER_NODES" ]; then
    log_message "Control planes and worker nodes are up and running."
else
    log_message "Error: Incorrect number of control planes or worker nodes."
 fi

# 7. Verify the Cluster Identity Secrets
log_message "Verifying the Cluster Identity Secrets..."
if ! retry "kubectl --kubeconfig=$KUBECONFIG_PATH get secrets | grep cluster-identity > /dev/null 2>&1"; then
    log_message "Error: Cluster Identity Secrets not found."
    exit 1
else
    log_message "Cluster Identity Secrets are present."
fi

# 8. Verify CAPZ components are installed
log_message "Verifying CAPZ components are installed..."
for COMPONENT in "${CAPZ_COMPONENTS[@]}"; do
    if ! retry "kubectl --kubeconfig=$KUBECONFIG_PATH get pods --all-namespaces | grep \"$COMPONENT\" | grep Running > /dev/null 2>&1"; then
        log_message "Error: $COMPONENT is not installed."
        exit 1
    else
        log_message "$COMPONENT is installed."
    fi
done

# 9. Verify the Management cluster nodes are spread across the 3 different Zones for High Availability
log_message "Verifying the Management cluster nodes are spread across the 3 different Zones for High Availability..."
if ! retry "az vmss show --name \"$VMSS_NAME\" --query \"zones\" | grep '$expected_zones' > /dev/null 2>&1"; then
    log_message "Error: VMSS is not configured with three failure domains."
    exit 1
else
    log_message "VMSS is configured with three failure domains."
fi

# Assert
log_message "### Assert ###"
log_message "All verifications completed successfully."
