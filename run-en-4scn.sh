#!/bin/bash

PROJ_PATH=$(pwd)
set -e

# Check if terraform.tfvars exists
if [[ ! -f "$(pwd)/klaytn-terraform/service-chain-aws/deploy-4scn/terraform.tfvars" ]]
then
	echo "Please prepare the configuration file for the klaytn-terraform."
	exit 1
fi

# Run terraform to initialize new VMs for nodes
./1.init_nodes.sh

# Run ansible klaytn_node
./2.setup_nodes.sh

## Wait 30 seconds for the Klaytn services to be restarted
echo "Waiting 30 seconds for the Klaytn services to be restarted"
sleep 30

# Wait until EN sync finished
echo "The newly deployed EN node should be synced to latest block. This could take about 30~40 minutes, up to few hours."
pushd klaytn-terraform/service-chain-aws/deploy-4scn
EN_PUBLIC_IP_LIST=($(terraform show -json | jq -r '.values.root_module.resources[] | select(.address | startswith("aws_eip_association.en")) | .values.public_ip'))
EN_IP=${EN_PUBLIC_IP_LIST[0]}
popd

## Reset timer to track elapsed time
SECONDS=0
while :
do
	EN_SYNCING=$(ssh ec2-user@$EN_IP "sudo ken attach /var/kend/data/klay.ipc --exec klay.syncing")
	DURATION=$SECONDS
	if [[ $EN_SYNCING == false ]]; then
		echo "EN node sync with Baobab finished in $(($DURATION / 60))m $(($DURATION % 60))s"
		break
	fi
	EN_BLOCK_NUM=$(ssh ec2-user@$EN_IP "sudo ken attach /var/kend/data/klay.ipc --exec klay.blockNumber")
	BAOBAB_BLOCK_NUM=$(ssh ec2-user@$EN_IP "sudo ken attach https://api.baobab.klaytn.net:8651 --exec klay.blockNumber")
	echo -ne "Syncing EN node with Baobab... ($(($DURATION / 60))m $(($DURATION % 60))s elapsed, $EN_BLOCK_NUM/$BAOBAB_BLOCK_NUM blocks synced)"\\r
	sleep 3
done

# Run ansible klaytn_bridge
./3.setup_bridge.sh

## Wait 30 seconds for the Klaytn services to be restarted
echo "Waiting 30 seconds for the Klaytn services to be restarted"
sleep 30

# Prompt the user to deposit some klay to parent bridge operator and parent sender
PARENT_OPERATOR=$(jq .parent.operator $PROJ_PATH/klaytn-ansible/bridge_info.json | tr -d '"')
PARENT_KEY=$(jq .parent.key $PROJ_PATH/klaytn-ansible/bridge_info.json)
PARENT_SENDER=$(ssh ec2-user@$EN_IP "sudo ken attach /var/kend/data/klay.ipc --exec 'personal.importRawKey($PARENT_KEY, \"\")'" | tr -d '"')
if [[ ! $PARENT_SENDER == 0x* ]]
then
	PARENT_SENDER=$(ssh ec2-user@$EN_IP "sudo ken attach /var/kend/data/klay.ipc --exec \"personal.listAccounts[0]\"" | tr -d '"')
fi

## First, parent bridge operator
while :
do
	PARENT_OPERATOR_BALANCE=$(ssh ec2-user@$EN_IP "sudo ken attach /var/kend/data/klay.ipc --exec \"klay.getBalance('$PARENT_OPERATOR')\"")
	if [[ $PARENT_OPERATOR_BALANCE == "0" ]]; then
		echo "Please send 10 Klay to \"$PARENT_OPERATOR\" using Baobab faucet (https://baobab.wallet.klaytn.com/access?next=faucet)"
	else
		break
	fi
	read -p "Type anything after you have sent 10 Klay to above account: " USER_INPUT
done
## Then, parent sender
while :
do
	PARENT_SENDER_BALANCE=$(ssh ec2-user@$EN_IP "sudo ken attach /var/kend/data/klay.ipc --exec \"klay.getBalance('$PARENT_SENDER')\"")
	if [[ $PARENT_SENDER_BALANCE == "0" ]]; then
		echo "Please send 100 Klay to \"$PARENT_SENDER\" using Baobab faucet (https://baobab.wallet.klaytn.com/access?next=faucet)"
	else
		break
	fi
	read -p "Type anything after you have sent 100 Klay to above account: " USER_INPUT
done

# TODO: Find a better way to make sure users deposit enough funds before running value transfer.
#       Also, the user might have to deposit funds several times to run value transfer multiple times.
echo "######################################################################
echo "[WARNING] Make sure that the addresses corresponding to parent.operator and parent.key in bridge_info.json have sufficient funds before value transfer."
echo "          parent.operator: $PARENT_OPERATOR \(10 Klay would be enough\)"
echo "          parent.key: $PARENT_KEY"
echo "          address derived from parent.key: $PARENT_SENDER \(100 Klay would be enough\)"
echo "######################################################################

# Test value transfer
./4.test_value_transfer.sh
