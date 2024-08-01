#!/bin/bash
 
# Test script to verify Istio Ingress installation and functionality
 
# Arrange
istio_namespace="istio-system"
ingress_app_namespace="default"
ingress_service_name="istio-ingressgateway"
application_name="my-app"
application_port=80
timestamp=$(date +"%y%m%d_%H%M%S")
output_dir="logs"
log_file="${output_dir}/Istio_Ingress_verification_${timestamp}.log"
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
  echo "$(date +"%y-%m-%d %H:%M:%S") - $message" | tee -a "$log_file"
}
 
# Ensure kubectl is installed
if ! command -v kubectl &> /dev/null; then
  echo "kubectl could not be found. Please install it."
fi
 
# Function to retry a command
retry() {
  local retries=3
  local delay=5
  shift 2
  local count=0
  until "$@"; do
    exit_code=$?
    count=$((count + 1))
    if [ $count -le $retries ]; then
      log_message "Attempt $count/$retries failed with exit code $exit_code, retrying in $delay seconds..."
      sleep $delay
    else
      log_message "Attempt $count/$retries failed with exit code $exit_code, no more retries left."
      return $exit_code
    fi
  done
  return 0
}
 
# Function to check if Istio Ingress is installed
verify_istio_ingress_installed() {
  log_message "Starting verification of Istio Ingress installation..."
  retry $retries $delay kubectl get pods -n $istio_namespace -l app=istio-ingressgateway --no-headers
  ingress_pods=$(kubectl get pods -n $istio_namespace -l app=istio-ingressgateway --no-headers)
  if [ -z "$ingress_pods" ]; then 
    errors+=("Istio Ingress is not installed")
  fi
  log_message "Completed verification of Istio Ingress installation."
}
 
# Function to check the status of Istio system pods
verify_istio_pods_status() {
  log_message "Starting verification of Istio pods status..."
 retry $retries $delay kubectl get pods -n $istio_namespace -o jsonpath='{range .items[*]}{.metadata.name} {.status.phase}{"\n"}{end}' > /tmp/istio_pods.txt
  if [ $? -ne 0 ]; then
    errors+=("Failed to retrieve Istio pods status")
    return
  fi
 
  while IFS= read -r line; do
    log_message "Processing pod status line: $line"
    pod_status=$(echo "$line" | awk '{print $2}')
    if [ "$pod_status" != "Running" ]; then
      errors+=("Istio pod not in 'Running' state: $line")
    fi
  done < /tmp/istio_pods.txt
  log_message "Completed verification of Istio pods status."
}
 
# Function to verify access to the application using the assigned Ingress IP
verify_application_access() {
  log_message "Starting verification of application access..."
  retry $retries $delay kubectl get svc $ingress_service_name -n $istio_namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' > /tmp/ingress_ip.txt
  if [ $? -ne 0 ]; then
    errors+=("Could not retrieve Ingress IP")
    return
  fi
 
  ingress_ip=$(cat /tmp/ingress_ip.txt)
  if [ -z "$ingress_ip" ]; then
    errors+=("Ingress IP is empty")
    return
  fi
 
  retry  curl -s -o /dev/null -w "%{http_code}" http://$ingress_ip:$application_port > /tmp/curl_response.txt
  response=$(cat /tmp/curl_response.txt)
  if [ "$response" -ne 200 ]; then
    errors+=("Failed to access application using Ingress IP: $ingress_ip")
  fi
  log_message "Completed verification of application access."
}
 
# Act
log_message "Starting the verification process..."
verify_istio_ingress_installed
verify_istio_pods_status
verify_application_access
log_message "Verification process completed."
 
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