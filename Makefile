SHELL := /bin/bash
TF    ?= terraform
ENV   ?= dev

.PHONY: init fmt validate plan apply destroy \
	localstack-up localstack-down ls-init ls-plan ls-apply ls-destroy \
	aws-sbx-plan aws-sbx-apply aws-sbx-destroy

init:
	$(TF) init -upgrade

fmt:
	$(TF) fmt -recursive

validate:
	$(TF) validate

plan:
	$(TF) plan -var-file=$(ENV).tfvars

apply:
	$(TF) apply -var-file=$(ENV).tfvars -auto-approve

destroy:
	$(TF) destroy -var-file=$(ENV).tfvars -auto-approve

localstack-up:
	docker compose -f examples/localstack/docker-compose.yml up -d

localstack-down:
	docker compose -f examples/localstack/docker-compose.yml down

ls-init:
	cd examples/localstack && terraform init

ls-plan:
	cd examples/localstack && terraform plan

ls-apply:
	cd examples/localstack && ./lambda/build.sh && terraform apply -auto-approve

ls-destroy:
	cd examples/localstack && terraform destroy -auto-approve

aws-sbx-plan:
	cd examples/aws-sandbox && terraform plan

aws-sbx-apply:
	cd examples/aws-sandbox && bash lambda_hello/build.sh && terraform apply -auto-approve

aws-sbx-destroy:
	cd examples/aws-sandbox && terraform destroy -auto-approve
