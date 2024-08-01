#!/bin/bash
# Test script for AKS-flavored cluster
 
# Variables
cluster_definition="path/to/your/cluster-definition.yaml"
cluster_kubeconfig="path/to/your/cluster.kubeconfig"
cluster_name="my-cluster"
namespace="default"
timestamp=$(date +%Y%m%d_%H%M%S)
output_dir="logs"
log_file="${output_dir}/AKS_Workload_$timestamp.log"
errors=()
retry_attempts=3
retry_delay=5
 
# Create the logs directory if it doesn't exist
if [ ! -d "$output_dir" ]; then
  mkdir -p "$output_dir"
  echo "Directory '$output_dir' created."
else
  echo "Directory '$output_dir' already exists."
fi
 
# Function to log messages with timestamp
log_message() {
  local message=$1
  echo "$(date +%y-%m-%d_%H:%M:%S) - $message" | tee -a "$log_file"
  }
 
# Ensure clusterctl and kubectl are installed
check_tools() {
  if ! command -v clusterctl &> /dev/null; then
    log_message "clusterctl could not be found. Please install it."
    return 1
  fi
 
  if ! command -v kubectl &> /dev/null; then
    log_message "kubectl could not be found. Please install it."
    return 1
  fi
 
  return 0
}
 
# Retry function
retry() {
  local n=1
  local max=$retry_attempts
  local delay=$retry_delay
  local command="$@"
 
  until eval "$command"; do
    if (( n == max )); then
      log_message "Command '$command' failed after $n attempts."
      return 1
    else
      log_message "Command '$command' failed. Attempt $n/$max:"
      ((n++))
      sleep $delay
    fi
  done
  log_message "Command '$command' succeeded on attempt $n."
  return 0
}
 
# To provision the cluster
provision_cluster() {
  export KUBECONFIG=$cluster_kubeconfig
  clusterctl init --infrastructure azure
  kubectl apply -f "$cluster_definition"
}
 
# To verify cluster creation
verify_cluster_creation() {
  export KUBECONFIG=$cluster_kubeconfig
  cluster_status=$(kubectl get cluster "$cluster_name" -o jsonpath='{.status.phase}' -n "$namespace")
  if [ "$cluster_status" != "Provisioned" ]; then
    errors+=("Cluster is not in 'Provisioned' state: $cluster_status")
    return 1
  fi
  return 0
}
 
# To verify node status
verify_node_status() {
  export KUBECONFIG=$cluster_kubeconfig
  nodes_status=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name} {.status.conditions[-1].type} {.status.conditions[-1].status}{"\n"}{end}')
  while IFS= read -r line; do
    node_status=$(echo "$line" | awk '{print $3}')
    if [ "$node_status" != "True" ]; then
      errors+=("Node status not 'Ready': $line")
      return 1
    fi
  done <<< "$nodes_status"
  return 0
}
 
# Function to verify pod deployment status
verify_pod_status() {
  export KUBECONFIG=$cluster_kubeconfig
  pods_status=$(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace} {.metadata.name} {.status.phase}{"\n"}{end}')
  while IFS= read -r line; do
    pod_status=$(echo "$line" | awk '{print $3}')
    if [ "$pod_status" != "Running" ] && [ "$pod_status" != "Succeeded" ]; then
      errors+=("Pod not in 'Running' or 'Succeeded' state: $line")
      return 1
    fi
  done <<< "$pods_status"
  return 0
}
 
# Function to verify cluster add-ons
verify_cluster_addons() {
  # Example check for a specific addon
  addon_status=$(kubectl get pods -n kube-system -l app=addon-name -o jsonpath='{.items[*].status.phase}')
  if [[ ! "$addon_status" =~ "Running" ]]; then
    errors+=("Cluster add-on 'addon-name' is not running")
    return 1
  fi
  return 0
}
 
# Ensure tools are available
retry check_tools
 
# Act
retry provision_cluster
 
# Assert
retry verify_cluster_creation
retry verify_node_status
retry verify_pod_status
retry verify_cluster_addons
 
# Log final message
log_message "### Assert ###"
 
if [ ${#errors[@]} -eq 0 ]; then
  log_message "Test passed: All checks are successful."
else
  log_message "Test failed:"
  for error in "${errors[@]}"; do
    log_message "  - $error"
  done
fi
 
# Output the results
cat "$log_file"

