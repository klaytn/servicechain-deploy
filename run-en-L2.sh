#!/bin/bash

PROJ_PATH=$(pwd)
set -e

# Prepare terraform.tfvars
#./0.prepare.sh en-L2

# Run terraform to initialize new VMs for nodes
./1.init_nodes.sh en-L2

# Run ansible klaytn_node
./2.setup_nodes.sh

# Wait until EN sync finished
echo "The newly deployed EN node should be synced to latest block. This could take about 30~40 minutes, up to few hours."
sleep 30
pushd klaytn-terraform/service-chain-aws/deploy-scn-spn-sen
EN_PUBLIC_IP_LIST=($(terraform show -json | jq -r '.values.root_module.resources[] | select(.address | startswith("aws_eip_association.en")) | .values.public_ip'))
EN_IP=${EN_PUBLIC_IP_LIST[0]}
popd

## Reset timer to track elapsed time
SECONDS=0
while :
do
	EN_SYNCING=$(ssh -i ~/.ssh/servicechain-deploy-key ec2-user@$EN_IP "sudo ken attach /var/kend/data/klay.ipc --exec klay.syncing")
	DURATION=$SECONDS
	if [[ $EN_SYNCING == false ]]; then
		echo "EN node sync with Baobab finished in $(($DURATION / 60))m $(($DURATION % 60))s"
		break
	fi
	EN_BLOCK_NUM=$(ssh -i ~/.ssh/servicechain-deploy-key ec2-user@$EN_IP "sudo ken attach /var/kend/data/klay.ipc --exec klay.blockNumber")
	BAOBAB_BLOCK_NUM=$(ssh -i ~/.ssh/servicechain-deploy-key ec2-user@$EN_IP "sudo ken attach https://api.baobab.klaytn.net:8651 --exec klay.blockNumber")
	echo -ne "Syncing EN node with Baobab... ($(($DURATION / 60))m $(($DURATION % 60))s elapsed, $EN_BLOCK_NUM/$BAOBAB_BLOCK_NUM blocks synced)"\\r
	sleep 3
done

# Run ansible klaytn_bridge
./3.setup_bridge.sh
