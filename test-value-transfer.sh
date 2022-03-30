#!/bin/bash

PROJ_PATH=$(pwd)

set -e

# Get number of bridge
BRIDGE_COUNT=$(egrep '^PARENT[0-9]+' $PROJ_PATH/inventory.bridge | wc -l)

PARENT_RPC_IP=()
PARENT_OPERATOR=()
PARENT_KEY=()
PARENT_SENDER=()
for ((i=0;i<$BRIDGE_COUNT;i++)); do
	PARENT_RPC_IP+=($(jq .parent.url $PROJ_PATH/klaytn-ansible/bridge_info$i.json | tr -d '"' | sed 's/\:[[:digit:]]*$//' | sed 's/http\:\/\///'))
	PARENT_OPERATOR+=($(jq .parent.operator $PROJ_PATH/klaytn-ansible/bridge_info$i.json | tr -d '"'))
	PARENT_KEY+=($(jq .parent.key $PROJ_PATH/klaytn-ansible/bridge_info$i.json))
	SENDER=$(ssh ec2-user@${PARENT_RPC_IP[$i]} "sudo ken attach /var/kend/data/klay.ipc --exec 'personal.importRawKey(${PARENT_KEY[$i]}, \"\")'" | tr -d '"')
	if [[ ! $SENDER == 0x* ]]
	then
		SENDER=$(ssh ec2-user@${PARENT_RPC_IP[$i]} "sudo ken attach /var/kend/data/klay.ipc --exec \"personal.listAccounts[0]\"" | tr -d '"')
	fi
	PARENT_SENDER+=($SENDER)
done

# TODO: Find a better way to make sure users deposit enough funds before running value transfer.
#       Also, the user might have to deposit funds several times to run value transfer multiple times.
echo "######################################################################"
echo "[WARNING] Make sure that the addresses corresponding to parent.operator and parent.key in bridge_info*.json have sufficient funds before value transfer."
for ((i=0;i<$BRIDGE_COUNT;i++)); do
	echo "          parent.operator[$i]: ${PARENT_OPERATOR[$i]} \(10 Klay would be enough\)"
	echo "          parent.key[$i]: ${PARENT_KEY[$i]}"
	echo -e "          address derived from parent.key[$i]: ${PARENT_SENDER[$i]} \(100 Klay would be enough\)\n"
done
echo "######################################################################"


# Prompt the user to deposit some klay to parent bridge operator and parent sender
for ((i=0;i<$BRIDGE_COUNT;i++)); do
	## First, parent bridge operator
	while :
	do
		PARENT_OPERATOR_BALANCE=$(ssh ec2-user@${PARENT_RPC_IP[$i]} "sudo ken attach /var/kend/data/klay.ipc --exec \"klay.getBalance('${PARENT_OPERATOR[$i]}')\"")
		if [[ $PARENT_OPERATOR_BALANCE == "0" ]]; then
			echo "Please send 10 Klay to \"${PARENT_OPERATOR[$i]}\" using Baobab faucet (https://baobab.wallet.klaytn.com/access?next=faucet)"
		else
			break
		fi
		read -p "Hit <enter> to continue: " USER_INPUT
	done
	## Then, parent sender
	while :
	do
		PARENT_SENDER_BALANCE=$(ssh ec2-user@${PARENT_RPC_IP[$i]} "sudo ken attach /var/kend/data/klay.ipc --exec \"klay.getBalance('${PARENT_SENDER[$i]}')\"")
		if [[ $PARENT_SENDER_BALANCE == "0" ]]; then
			echo "Please send 100 Klay to \"${PARENT_SENDER[$i]}\" using Baobab faucet (https://baobab.wallet.klaytn.com/access?next=faucet)"
		else
			break
		fi
		read -p "Hit <enter> to continue: " USER_INPUT
	done
done

# Test value transfer
## First, install dependencies
pushd value-transfer
cp $PROJ_PATH/klaytn-ansible/bridge_info0.json common/bridge_info.json
npm install

## Then, deploy using first bridge
pushd erc20
node erc20-deploy.js

## Get  bridge info
PARENT_BRIDGE=$(jq .parent.bridge $PROJ_PATH/value-transfer/erc20/transfer_conf.json)
CHILD_BRIDGE=$(jq .child.bridge $PROJ_PATH/value-transfer/erc20/transfer_conf.json)
PARENT_TOKEN=$(jq .parent.token $PROJ_PATH/value-transfer/erc20/transfer_conf.json)
CHILD_TOKEN=$(jq .child.token $PROJ_PATH/value-transfer/erc20/transfer_conf.json)

## Test ERC20 value transfer
## Deploy remaining bridges
### This loop starts from 1, because bridge[0] is handled by erc20-deploy.js
for ((i=1;i<$BRIDGE_COUNT;i++)); do
	CHILD_RPC_IP=$(jq .child.url $PROJ_PATH/klaytn-ansible/bridge_info$i.json | tr -d '"' | sed 's/\:[[:digit:]]*$//' | sed 's/http\:\/\///')
	ssh -q centos@$CHILD_RPC_IP "sudo kscn attach /var/kscnd/data/klay.ipc --exec \"subbridge.registerBridge('$CHILD_BRIDGE','$PARENT_BRIDGE')\"; \
		sudo kscn attach /var/kscnd/data/klay.ipc --exec \"subbridge.subscribeBridge('$CHILD_BRIDGE', '$PARENT_BRIDGE')\"; \
		sudo kscn attach /var/kscnd/data/klay.ipc --exec \"subbridge.registerToken('$CHILD_BRIDGE', '$PARENT_BRIDGE', '$CHILD_TOKEN', '$PARENT_TOKEN')\""
done

## Run transfer
node erc20-transfer-1step.js

popd
popd
