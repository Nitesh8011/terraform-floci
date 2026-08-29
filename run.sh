#!/bin/bash
set -euo pipefail

step() {
  echo ""
  echo "=========================================="
  echo " $1"
  echo "=========================================="
  echo ""
}

step "FORMAT"
terraform fmt -recursive
step "FORMATTED"

step "SELECT WORKSPACE"
echo "Select the workspace to apply changes to:"
select WORKSPACE in "staging" "production"; do
  case "$WORKSPACE" in
    staging|production) break ;;
    *) echo "Invalid choice. Please select 1 or 2." ;;
  esac
done
echo "Using workspace: $WORKSPACE"
terraform workspace select "$WORKSPACE"

VAR_FILE="${WORKSPACE}.tfvars"

step "VALIDATE"
terraform validate

step "PLAN"
terraform plan -var-file="$VAR_FILE"

step "APPLING"
terraform apply -var-file="$VAR_FILE"
