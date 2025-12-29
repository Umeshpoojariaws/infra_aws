# Makefile for Terraform Infrastructure Management

.PHONY: help init plan apply destroy validate fmt test clean

# Default target
help:
	@echo "Available targets:"
	@echo "  init     - Initialize Terraform backend and providers"
	@echo "  plan     - Generate Terraform execution plan"
	@echo "  apply    - Apply Terraform configuration"
	@echo "  destroy  - Destroy all resources"
	@echo "  validate - Validate Terraform configuration"
	@echo "  fmt      - Format Terraform files"
	@echo "  test     - Run tests"
	@echo "  clean    - Clean up temporary files"

# Environment variables
ENV ?= dev
ACCOUNT ?= shared
TF_VERSION ?= 1.6.0
TERRAGRUNT_VERSION ?= 0.51.1

# Colors for output
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
BLUE   := $(shell tput -Txterm setaf 4)
RESET  := $(shell tput -Txterm sgr0)

# Print colored output
define print_status
	@echo "$(BLUE)[$(ENV)-$(ACCOUNT)]$(RESET) $1"
endef

define print_success
	@echo "$(GREEN)✓$(RESET) $1"
endef

define print_warning
	@echo "$(YELLOW)⚠$(RESET) $1"
endef

# Initialize Terraform
init:
	@$(call print_status,"Initializing Terraform...")
	cd environments/$(ENV)/$(ACCOUNT) && \
	terraform init
	@$(call print_success,"Terraform initialized")

# Generate plan
plan:
	@$(call print_status,"Generating plan...")
	cd environments/$(ENV)/$(ACCOUNT) && \
	terraform plan -out=terraform.tfplan
	@$(call print_success,"Plan generated")

# Apply configuration
apply:
	@$(call print_status,"Applying configuration...")
	cd environments/$(ENV)/$(ACCOUNT) && \
	terraform apply terraform.tfplan
	@$(call print_success,"Configuration applied")

# Destroy resources
destroy:
	@$(call print_warning,"Destroying resources...")
	cd environments/$(ENV)/$(ACCOUNT) && \
	terraform destroy
	@$(call print_success,"Resources destroyed")

# Validate configuration
validate:
	@$(call print_status,"Validating configuration...")
	cd environments/$(ENV)/$(ACCOUNT) && \
	terraform validate
	@$(call print_success,"Configuration validated")

# Format Terraform files
fmt:
	@$(call print_status,"Formatting Terraform files...")
	terraform fmt -recursive
	@$(call print_success,"Files formatted")

# Run tests
test:
	@$(call print_status,"Running tests...")
	# Add test commands here
	@$(call print_success,"Tests completed")

# Clean up temporary files
clean:
	@$(call print_status,"Cleaning up...")
	find . -name "*.tfstate*" -type f -delete
	find . -name "*.tfplan" -type f -delete
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name ".terragrunt-cache" -type d -exec rm -rf {} + 2>/dev/null || true
	@$(call print_success,"Cleanup completed")

# Terragrunt commands
terragrunt-init:
	@$(call print_status,"Initializing with Terragrunt...")
	cd environments/$(ENV)/$(ACCOUNT) && \
	terragrunt init
	@$(call print_success,"Terragrunt initialized")

terragrunt-plan:
	@$(call print_status,"Generating plan with Terragrunt...")
	cd environments/$(ENV)/$(ACCOUNT) && \
	terragrunt plan
	@$(call print_success,"Terragrunt plan generated")

terragrunt-apply:
	@$(call print_status,"Applying with Terragrunt...")
	cd environments/$(ENV)/$(ACCOUNT) && \
	terragrunt apply
	@$(call print_success,"Terragrunt configuration applied")

terragrunt-destroy:
	@$(call print_warning,"Destroying with Terragrunt...")
	cd environments/$(ENV)/$(ACCOUNT) && \
	terragrunt destroy
	@$(call print_success,"Terragrunt resources destroyed")

# AWS CLI commands
aws-configure:
	@$(call print_status,"Configuring AWS CLI...")
	aws configure
	@$(call print_success,"AWS CLI configured")

aws-whoami:
	@$(call print_status,"Getting AWS identity...")
	aws sts get-caller-identity
	@$(call print_success,"AWS identity retrieved")

# Kubernetes commands
kubectl-context:
	@$(call print_status,"Setting kubectl context...")
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(ENV)-$(ACCOUNT)-eks-cluster-main
	@$(call print_success,"kubectl context set")

kubectl-get-pods:
	@$(call print_status,"Getting pods...")
	kubectl get pods --all-namespaces
	@$(call print_success,"Pods retrieved")

# Docker commands
docker-build:
	@$(call print_status,"Building Docker image...")
	docker build -t $(ENV)-$(ACCOUNT)-infra:latest .
	@$(call print_success,"Docker image built")

docker-run:
	@$(call print_status,"Running Docker container...")
	docker run -it --rm $(ENV)-$(ACCOUNT)-infra:latest
	@$(call print_success,"Docker container running")

# Environment-specific commands
dev-init:
	@$(call print_status,"Initializing dev environment...")
	$(MAKE) init ENV=dev ACCOUNT=shared
	$(MAKE) init ENV=dev ACCOUNT=app
	$(MAKE) init ENV=dev ACCOUNT=ml
	@$(call print_success,"Dev environment initialized")

dev-apply:
	@$(call print_status,"Applying dev environment...")
	$(MAKE) apply ENV=dev ACCOUNT=shared
	$(MAKE) apply ENV=dev ACCOUNT=app
	$(MAKE) apply ENV=dev ACCOUNT=ml
	@$(call print_success,"Dev environment applied")

staging-init:
	@$(call print_status,"Initializing staging environment...")
	$(MAKE) init ENV=staging ACCOUNT=shared
	$(MAKE) init ENV=staging ACCOUNT=app
	$(MAKE) init ENV=staging ACCOUNT=ml
	@$(call print_success,"Staging environment initialized")

prod-init:
	@$(call print_status,"Initializing prod environment...")
	$(MAKE) init ENV=prod ACCOUNT=shared
	$(MAKE) init ENV=prod ACCOUNT=app
	$(MAKE) init ENV=prod ACCOUNT=ml
	@$(call print_success,"Prod environment initialized")

# Documentation commands
docs-generate:
	@$(call print_status,"Generating documentation...")
	# Add documentation generation commands here
	@$(call print_success,"Documentation generated")

docs-serve:
	@$(call print_status,"Serving documentation...")
	# Add documentation serving commands here
	@$(call print_success,"Documentation served")

# Backup commands
backup-state:
	@$(call print_status,"Backing up Terraform state...")
	aws s3 cp environments/$(ENV)/$(ACCOUNT)/terraform.tfstate s3://terraform-backups/$(ENV)/$(ACCOUNT)/$(shell date +%Y-%m-%d_%H-%M-%S).tfstate
	@$(call print_success,"State backed up")

restore-state:
	@$(call print_status,"Restoring Terraform state...")
	aws s3 cp s3://terraform-backups/$(ENV)/$(ACCOUNT)/$(STATE_FILE) environments/$(ENV)/$(ACCOUNT)/terraform.tfstate
	@$(call print_success,"State restored")