#!/bin/bash

set -e

# 0. Check dependencies
echo "Checking dependencies..."
which jq
which curl
which tr
which node
which aws
aws sts get-caller-identity
which terraform
which ansible-playbook
echo "Done."

# 1. Create SSH key if not exist
if [[ ! -f "$HOME/.ssh/servicechain-deploy-key" ]]
then
	ssh-keygen -b 2048 -t rsa -f $HOME/.ssh/servicechain-deploy-key -q -N ""
fi

SSH_PUBKEY=$(cat $HOME/.ssh/servicechain-deploy-key)

# 2. Exit if terraform.tfvars exist
if [[ -f "$(pwd)/klaytn-terraform/service-chain-aws/terraform.tfvars" ]]
then
	exit 0
fi

echo "Seems like you haven't prepared 'terraform.tfvars'. Do you want to create VPC and 'terraform.tfvars' with default settings now?"
select yn in "Yes" "No"; do
	case $yn in
		Yes ) break;;
		No ) exit;;
	esac
done

# Create VPC
pushd $(pwd)/klaytn-terraform/service-chain-aws/create_vpc
terraform init
terraform apply
VPC_ID=$(terraform output -json | jq .vpc_id.value | tr -d '"')
SUBNET_ID=$(terraform output -json | jq .public_subnet_ids.value[0] | tr -d '"')
popd

# Get public IP address of me
MY_IP=$(curl ifconfig.me)

# Create terraform.tfvars
cat $(pwd)/klaytn-terraform/service-chain-aws/terraform.tfvars <<EOF
name="servicechain-deploy"
region="ap-northeast-2"
vpc_id="$VPC_ID"
en_subnet_ids = ["$SUBNET_ID"]
scn_subnet_ids = ["$SUBNET_ID"]
ssh_client_ips = ["$MY_IP/32"]
ssh_pub_key = "$SSH_PUBKEY"
EOF
