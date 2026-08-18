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
terraform fmt

step "VALIDATE"
terraform validate

step "PLAN"
terraform plan

step "APPLING"
terraform apply
