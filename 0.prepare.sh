#!/bin/bash

set -e

usage() {
	echo "Usage: $0 <case>"
	echo ""
	echo "Cases:"
	echo "    en-4scn: Deploy Cypress/Baobab EN and 4 SCNs"
	echo "    en-L2: Deploy Cypress/Baobab EN and ServiceChain nodes including SCN, SPN, SEN"
	echo "    L1-L2: Deploy private L1 network and ServiceChain nodes including SCN, SPN, SEN"
	echo "    L2: Deploy L2 and bridge to existing chain (Cypress/Baobab or another ServiceChain)"
	echo ""
	exit 1
}

# 0. Check dependencies
check_dependency() {
echo "Checking dependencies..."
which jq
which curl
which tr
which sed
which node
which aws
aws sts get-caller-identity
which terraform
which ansible-playbook
echo "Done."
}

# 1. Create SSH key if not exist
create_ssh_key() {
if [[ ! -f "$HOME/.ssh/servicechain-deploy-key" ]]
then
	ssh-keygen -b 2048 -t rsa -f $HOME/.ssh/servicechain-deploy-key -q -N ""
fi

SSH_PUBKEY=$(cat $HOME/.ssh/servicechain-deploy-key.pub)
}

# 2. Exit if terraform.tfvars exist
check_terraform_tfvars() {
	# First, check if file exists
	if [[ -f "$(pwd)/klaytn-terraform/service-chain-aws/$1/terraform.tfvars" ]]
	then
		# Then check if that file has any content that isn't comment
		if grep -q -v -e '^\#' klaytn-terraform/service-chain-aws/$1/terraform.tfvars; then
			echo "Seems like there's an existing 'terraform.tfvars'. Do you want to reuse that file without creating a new 'terraform.tfvars'?"
			select yn in "Yes" "No"; do
				case $yn in
					Yes ) exit 0;;
					No ) break;;
				esac
			done
		fi
	fi
	echo "Do you want to create VPC and 'terraform.tfvars' with default settings now?"
	select yn in "Yes" "No"; do
		case $yn in
			Yes ) break;;
			No ) exit 1;;
		esac
	done
}

# Create VPC
create_vpc() {
	# TODO: Fix typo after klaytn-terraform has been updated
	pushd $(pwd)/klaytn-terraform/serivce-chain-aws/create_vpc
	terraform init
	terraform apply
	VPC_ID=$(terraform output -json | jq .vpc_id.value | tr -d '"')
	SUBNET_ID=$(terraform output -json | jq .public_subnet_ids.value[0] | tr -d '"')
	popd
}

create_terraform_tfvars() {
	# Get public IP address of me
	MY_IP=$(curl ifconfig.me)

	# Create terraform.tfvars
	cat > $(pwd)/klaytn-terraform/service-chain-aws/$1/terraform.tfvars <<EOF
name="servicechain-deploy"
region="ap-northeast-2"
vpc_id="$VPC_ID"
cn_subnet_ids = ["$SUBNET_ID"]
pn_subnet_ids = ["$SUBNET_ID"]
en_subnet_ids = ["$SUBNET_ID"]
scn_subnet_ids = ["$SUBNET_ID"]
spn_subnet_ids = ["$SUBNET_ID"]
sen_subnet_ids = ["$SUBNET_ID"]
grafana_subnet_ids = ["$SUBNET_ID"]
cn_instance_count = "1"
pn_instance_count = "1"
en_instance_count = "1"
scn_instance_count = "4"
spn_instance_count = "2"
sen_instance_count = "2"
grafana_instance_count = "0"
ssh_client_ips = ["$MY_IP/32"]
ssh_pub_key = "$SSH_PUBKEY"
aws_key_pair_name = "servicechain-deploy"
EOF
}


target=$1
shift

case "$target" in
        en-4scn)
		check_dependency
		create_ssh_key
		check_terraform_tfvars deploy-4scn
		create_vpc
		create_terraform_tfvars deploy-4scn
                ;;
        en-L2)
		check_dependency
		create_ssh_key
		check_terraform_tfvars deploy-scn-spn-sen
		create_vpc
		create_terraform_tfvars deploy-scn-spn-sen
                ;;
        L1-L2)
		check_dependency
		create_ssh_key
		check_terraform_tfvars deploy-L1-L2
		create_vpc
		create_terraform_tfvars deploy-L1-L2
                ;;
	L2)
		check_dependency
		create_ssh_key
		check_terraform_tfvars deploy-multi_layer-servicechain
		create_vpc
		create_terraform_tfvars deploy-multi_layer-servicechain
		;;
        *)
                usage
                ;;
esac
