#!/bin/bash

#To verify CAPZ template file

#Arrange
template_file="path/to/your/capz_template.yaml"
timestamp=$(date +%y%m%d_%H%M%S)
output_dir="logs"
log_file="${output_dir}/Capz_Template_verification_$timestamp.log"
required_sections=("apiVersion" "kind" "metadata" "spec")
errors=()

# Create the logs directory if it doesn't 
if [! -d "$log_dir"]; then
mkdir -p "$log_dir"
echo " directory 'log_dir' created."
   else
  echo " directory 'log_dir' alredy exists"
  fi
  
#function to log messages with timestamp
log_messages() {
	local_message=$1
	echo "$(date +%y-%m-%d %H:%M:%S)" - $local_message	| tee -a 
	"$log_file"
	}

# To check for required sections
check_required_sections() {
  for section in "${required_sections[@]}"; do
    if ! grep -q "^${section}:" "$template_file"; then
      errors+=("Missing section: $section")
    fi
  done
}

# To check for correct usage of placeholders, loops, and conditions
check_placeholders_loops_conditions() {
  if grep -q "\{\{.*\}\}" "$template_file"; then
    errors+=("Unresolved placeholders found")
  fi

  #  checks for loops and conditions can be added 
}

# To check for correct YAML syntax
check_yaml_syntax() {
  if ! yamllint -d "{extends: default, rules: {line-length: disable}}" "$template_file"; then
    errors+=("YAML syntax errors found")
  fi
}

# To check for required fields and correct formatting
check_required_fields_formatting() {
  if ! grep -q "required_field: value" "$template_file"; then
    errors+=("Required field 'required_field' is missing or incorrectly formatted")
  fi
}

# Act
check_required_sections
check_placeholders_loops_conditions
check_yaml_syntax
check_required_fields_formatting
log_message


# Assert
log_message "### Assert ###"
if [ ${#errors[@]} -eq 0 ]; then 
  echo "Test passed: All checks are successful." >> $log_file
  "$log_file"
else
  echo "Test failed:" 
  "$log_file"
  for error in "${errors[@]}"; do 
  echo "  - $error" >> $log_file
  "$log_message" 
  done
fi

#output the results
cat "$log_file"

