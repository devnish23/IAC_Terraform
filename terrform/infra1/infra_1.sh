#!/bin/bash

# Get user input for variables
read -p "Enter the desired AWS region: " aws_region
read -p "Enter the instance type: " instance_type
read -p "Enter the key pair name: " key_name
read -p "Enter the AMI ID: " ami_id
read -p "Enter the instance_name: " instance_name 

# Export variables for Terraform
export TF_VAR_aws_region="$aws_region"
export TF_VAR_instance_type="$instance_type"
export TF_VAR_key_name="$key_name"
export TF_VAR_ami_id="$ami_id"
export TF_VAR_instance_name="$instance_name"

# Run Terraform script
terraform init 
terraform plan 
terraform apply

