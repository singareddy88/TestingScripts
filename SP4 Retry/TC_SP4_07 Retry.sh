#!/bin/bash
 
# Test script using Arrange-Act-Assert pattern for Git branch verification and restrictions
 
# Configuration
max_retries=3
retry_delay=5  # in seconds
 
# Define the repository and branch details
repo_directory="/path/to/your/repo"
feature_branch="feature/new-feature"
main_branch="main"
timestamp=$(date +%y%m%d_%H%M%S)
output_dir="logs"
log_file="${output_dir}/Git_Branch_verification_$timestamp.log"
errors=()
 
# Create the logs directory if it doesn't exist
if [ ! -d "$output_dir" ]; then
  mkdir -p "$output_dir"
  echo "Directory '$output_dir' created."
else
  echo "Directory '$output_dir' already exists."
fi
 
# Function to retry a command
retry() {
  local cmd="$1"
  local retries=0
  local success=0
 
  while [ $retries -lt $max_retries ]; do
    echo "Executing command: $cmd (Attempt $((retries + 1))/$max_retries)"
    eval "$cmd" &>/dev/null
    if [ $? -eq 0 ]; then
      success=1
      break
    else
      retries=$((retries + 1))
      echo "Command failed. Retry $retries/$max_retries..."
      sleep $retry_delay
    fi
  done
 
  if [ $success -ne 1 ]; then
    errors+=("Command failed after $max_retries retries: $cmd")
  fi
}
 
# Function to navigate to the repository directory
navigate_to_repo() {
  echo "Navigating to repository directory..."
  if [ -d "$repo_directory" ]; then
    cd "$repo_directory"
    if [ $? -ne 0 ]; then
      errors+=("Failed to navigate to repository directory: $repo_directory")
    fi
  else
    errors+=("Repository directory does not exist: $repo_directory")
  fi
}
 
# Function to verify the feature branch is created
verify_feature_branch() {
  echo "Verifying feature branch..."
  branches=$(git branch -a)
  if [[ ! "$branches" =~ "$feature_branch" ]]; then
    errors+=("Feature branch '$feature_branch' not found")
  fi
}
 
# Function to check for merge restrictions
check_merge_restrictions() {
  echo "Checking merge restrictions..."
  retry "git checkout $main_branch"
  merge_output=$(git merge --no-ff "$feature_branch" 2>&1)
  if [[ "$merge_output" =~ "error" || "$merge_output" =~ "fatal" ]]; then
    errors+=("Merge restriction error: $merge_output")
  else
    # Abort the merge if it went through to avoid unwanted changes
    retry "git merge --abort"
    if [ $? -eq 0 ]; then
      errors+=("Merge restriction not in place; merge proceeded without restriction")
    fi
  fi
}
 
# Function to verify changes in the feature branch
verify_changes_applied() {
  echo "Verifying changes in the feature branch..."
  retry "git checkout $feature_branch"
  changes=$(git diff "$main_branch" --name-only)
  if [ -z "$changes" ]; then
    errors+=("No changes detected in the feature branch")
  fi
}
 
# Act
echo "Starting the Arrange phase..."
navigate_to_repo
verify_feature_branch
check_merge_restrictions
verify_changes_applied
 
# Log results
log_message() {
  echo "Logging results..."
  if [ ${#errors[@]} -eq 0 ]; then
    echo "Test passed: All checks are successful." >> $log_file
  else
    echo "Test failed:" >> $log_file
    for error in "${errors[@]}"; do
      echo "  - $error" >> $log_file
    done
  fi
}
 
log_message
 
# Output the results
cat "$log_file"