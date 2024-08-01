#!/bin/bash
 
# To verify Calico installation and functionality
 
# Variables
calico_namespace="kube-system"
calico_label="k8s-app=calico-node"
timestamp=$(date +%Y%m%d_%H%M%S)
output_dir="logs"
log_file="${output_dir}/Calico_CNI_Installation_$timestamp.log"
errors=()
 
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
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$log_file"
}
 
# Retry function
retry() {
  local n=1
  local max=2
  local delay=5
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        log_message "Command failed. Attempt $n/$max:"
        sleep $delay
      else
        log_message "The command has failed after $n attempts."
        return 1
      fi
    }
  done
}
 
# Ensure kubectl is installed
check_kubectl_installed() {
  if ! command -v kubectl &> /dev/null; then
    log_message "kubectl could not be found. Please install it."
    return 1
  fi
  return 0
}
 
# Function to check if Calico is installed
verify_calico_installed() {
  retry kubectl get pods -n "$calico_namespace" -l "$calico_label" --no-headers
  if [ $? -ne 0 ]; then
    errors+=("Calico is not installed")
  fi
}
 
# Function to check the status of Calico pods
verify_calico_pods_status() {
  calico_pods=$(retry kubectl get pods -n "$calico_namespace" -l "$calico_label" -o jsonpath='{range .items[*]}{.metadata.name} {.status.phase}{"\n"}{end}')
  while IFS= read -r line; do
    pod_status=$(echo "$line" | awk '{print $2}')
    if [ "$pod_status" != "Running" ]; then
      errors+=("Calico pod not in 'Running' state: $line")
    fi
  done <<< "$calico_pods"
}
 
# Function to verify pod network connectivity
verify_pod_network_connectivity() {
  # Deploy two test pods
  retry kubectl run test-pod-1 --image=busybox --restart=Never -- sleep 3600
  retry kubectl run test-pod-2 --image=busybox --restart=Never -- sleep 3600
 
  # Wait for test pods to be running
  retry kubectl wait --for=condition=Ready pod/test-pod-1 --timeout=60s
  retry kubectl wait --for=condition=Ready pod/test-pod-2 --timeout=60s
 
  # Get the IP of the second test pod
  pod_ip=$(retry kubectl get pod test-pod-2 -o jsonpath='{.status.podIP}')
 
  # Verify network connectivity from the first test pod to the second test pod
  connectivity_status=$(retry kubectl exec test-pod-1 -- ping -c 1 "$pod_ip")
  if [[ ! "$connectivity_status" =~ "1 packets received" ]]; then
    errors+=("Pod network connectivity test failed")
  fi
 
  # Clean up test pods
  retry kubectl delete pod test-pod-1 test-pod-2
}
 
# Ensure kubectl is available
retry check_kubectl_installed
 
# Act
verify_calico_installed
verify_calico_pods_status
verify_pod_network_connectivity
 
# Assert
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