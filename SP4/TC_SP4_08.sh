#!/bin/bash

# Test script using Arrange-Act-Assert pattern to verify the authentication module in the management cluster template

# Arrange
template_path="/path/to/management-cluster-template.yaml"
required_parameters=("clientID" "clientSecret" "tenantID" "subscriptionID" "resourceGroupName")
ad_group="PermittedADGroup"
test_user="validUser@example.com"
non_existing_user="invalidUser@example.com"
timestamp=$(date +%y%m%d_%H%M%S)
output_dir="logs"
log_file="${output_dir}/capz_verification_$timestamp.log"
errors=()

# Create the logs directory if it doesn't 
if [! -d "$log_dir"]; then
mkdir -p "$log_dir"
echo " directory 'log_dir' created."
   else
  echo " directory 'log_dir' alredy exists"
  fi

# Ensure required tools are installed
if ! command -v kubectl &> /dev/null; then
  echo "kubectl could not be found. Please install it."
  exit 1
fi

if ! command -v az &> /dev/null; then
  echo "az CLI could not be found. Please install it."
  exit 1
fi

# Function to verify integration points and syntax in the template
verify_template_syntax() {
  if [ ! -f "$template_path" ]; then
    errors+=("Management cluster template not found: $template_path")
    return
  fi

  for param in "${required_parameters[@]}"; do
    if ! grep -q "$param" "$template_path"; then
      errors+=("Required parameter '$param' not found in template")
    fi
  done

  # Check if the YAML is well-formed
  if ! yq eval '.' "$template_path" &>/dev/null; then
    errors+=("Template syntax is invalid")
  fi
}

# Function to test integration status
test_integration_status() {
  # Assuming there are specific commands or logs to check integration status
  # Example: Checking the status of a deployed component
  if ! kubectl get pods -n kube-system | grep -q "auth-component"; then
    errors+=("Authentication component is not running")
  fi
}

# Function to test login with a valid user
test_login_valid_user() {
  # Simulate login with a valid user (replace with actual login logic)
  login_output=$(az login --username "$test_user" --password "validPassword" --service-principal --tenant "yourTenantID" 2>&1)
  if [[ "$login_output" =~ "error" ]]; then
    errors+=("Valid user login failed: $login_output")
  fi
}

# Function to test login with a non-existing user
test_login_invalid_user() {
  # Simulate login with a non-existing user (replace with actual login logic)
  login_output=$(az login --username "$non_existing_user" --password "invalidPassword" --service-principal --tenant "yourTenantID" 2>&1)
  if [[ ! "$login_output" =~ "error" ]]; then
    errors+=("Invalid user login succeeded, but it should fail")
  fi
}

# Act
verify_template_syntax
test_integration_status
test_login_valid_user
test_login_invalid_user
log_message

# Assert
if [ ${#errors[@]} -eq 0 ]; then
  echo "Test passed: All checks are successful." >> $log_file
  "$log_file"
else
  echo "Test failed:" >>
  "$log_file"
  for error in "${errors[@]}"; do
    echo "  - $error" >> $log_file
  done
fi
#output the results
cat "$log_file"

