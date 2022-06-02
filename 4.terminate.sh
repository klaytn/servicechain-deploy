#!/bin/bash

set -e

destroy_nodes() {
	# Terminate terraform deployed VMs
	pushd klaytn-terraform/service-chain-aws/$1
	terraform destroy

	popd
}

destroy_vpc() {
	# Terminate terraform created VPCs if exist
	#TODO: Fix typo after klaytn-terraform is updated
	pushd klaytn-terraform/serivce-chain-aws/create_vpc
	if [[ $(terraform show -no-color | tr -d '\n\r\t ' | wc -c) -eq 0 ]]; then
		exit
	fi
	echo "Seems like you have deployed a new VPC. Do you want to destroy previously created VPC?"
	select yn in "Yes" "No"; do
		case $yn in
			Yes ) break;;
			No ) exit;;
		esac
	done
	terraform destroy

	popd
}

destroy_nodes deploy-4scn
destroy_nodes deploy-scn-spn-sen
destroy_nodes deploy-L1-L2

destroy_vpc
