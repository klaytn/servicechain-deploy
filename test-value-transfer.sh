#!/bin/bash

PROJ_PATH=$(pwd)

set -e

# Get number of bridge
BRIDGE_COUNT=$(egrep '^PARENT[0-9]+' $PROJ_PATH/inventory.bridge | wc -l)

PARENT_SERVICE_TYPE=$(egrep '^PARENT0' $PROJ_PATH/inventory.bridge | sed 's/.*parent_service_type=\([[:alnum:]]*\).*/\1/' | tr -d 'd')
CHILD_SERVICE_TYPE=$(egrep '^CHILD0' $PROJ_PATH/inventory.bridge | sed 's/.*child_service_type=\([[:alnum:]]*\).*/\1/' | tr -d 'd')
PARENT_USERNAME=$(egrep '^PARENT0' $PROJ_PATH/inventory.bridge | sed 's/.*ansible_user=\([[:alnum:]]*\).*/\1/' | tr -d 'd')
CHILD_USERNAME=$(egrep '^CHILD0' $PROJ_PATH/inventory.bridge | sed 's/.*ansible_user=\([[:alnum:]]*\).*/\1/' | tr -d 'd')

PARENT_RPC_IP=$(jq .url.parent $PROJ_PATH/klaytn-ansible/bridge_info.json | tr -d '"' | sed 's/\:[[:digit:]]*$//' | sed 's/http\:\/\///')
PARENT_OPERATORS=($(jq -r '.bridges[].parent.operator' $PROJ_PATH/klaytn-ansible/bridge_info.json | tr -d '[]," '))
PARENT_KEY=$(jq .sender.parent.key $PROJ_PATH/klaytn-ansible/bridge_info.json)
PARENT_SENDER=$(ssh -i ~/.ssh/servicechain-deploy-key $PARENT_USERNAME@$PARENT_RPC_IP "sudo $PARENT_SERVICE_TYPE attach /var/${PARENT_SERVICE_TYPE}d/data/klay.ipc --exec 'personal.importRawKey($PARENT_KEY, \"\")'" | tr -d '"')
if [[ ! $PARENT_SENDER == 0x* ]]
then
	PARENT_SENDER=$(ssh -i ~/.ssh/servicechain-deploy-key $PARENT_USERNAME@$PARENT_RPC_IP "sudo $PARENT_SERVICE_TYPE attach /var/${PARENT_SERVICE_TYPE}d/data/klay.ipc --exec \"personal.listAccounts[0]\"" | tr -d '"')
fi

CHILD_RPC_IP=$(jq .url.child $PROJ_PATH/klaytn-ansible/bridge_info.json | tr -d '"' | sed 's/\:[[:digit:]]*$//' | sed 's/http\:\/\///')
CHILD_OPERATORS=($(jq -r '.bridges[].child.operator' $PROJ_PATH/klaytn-ansible/bridge_info.json | tr -d '[]," '))
CHILD_KEY=$(jq .sender.child.key $PROJ_PATH/klaytn-ansible/bridge_info.json)
CHILD_SENDER=$(ssh -i ~/.ssh/servicechain-deploy-key $CHILD_USERNAME@$CHILD_RPC_IP "sudo $CHILD_SERVICE_TYPE attach /var/${CHILD_SERVICE_TYPE}d/data/klay.ipc --exec 'personal.importRawKey($CHILD_KEY, \"\")'" | tr -d '"')
if [[ ! $CHILD_SENDER == 0x* ]]
then
	CHILD_SENDER=$(ssh -i ~/.ssh/servicechain-deploy-key $CHILD_USERNAME@$CHILD_RPC_IP "sudo $CHILD_SERVICE_TYPE attach /var/${CHILD_SERVICE_TYPE}d/data/klay.ipc --exec \"personal.listAccounts[0]\"" | tr -d '"')
fi

# TODO: Find a better way to make sure users deposit enough funds before running value transfer.
#       Also, the user might have to deposit funds several times to run value transfer multiple times.
echo "######################################################################"
echo "[WARNING] Make sure that the addresses corresponding to parent.operator and parent.key in bridge_info*.json have sufficient funds before value transfer."
for ((i=0;i<$BRIDGE_COUNT;i++)); do
	echo "          parent.operator[$i]: ${PARENT_OPERATORS[$i]} \(10 Klay would be enough\)"
done
echo "          parent.key: $PARENT_KEY"
echo -e "          address derived from parent.key: $PARENT_SENDER \(100 Klay would be enough\)\n"
echo "######################################################################"

# Prompt the user to deposit some klay to parent bridge operator and parent sender
for ((i=0;i<$BRIDGE_COUNT;i++)); do
	## First, parent bridge operator
	while :
	do
		PARENT_OPERATOR_BALANCE=$(ssh -i ~/.ssh/servicechain-deploy-key $PARENT_USERNAME@$PARENT_RPC_IP "sudo $PARENT_SERVICE_TYPE attach /var/${PARENT_SERVICE_TYPE}d/data/klay.ipc --exec \"klay.getBalance('${PARENT_OPERATORS[$i]}')\"")
		if [[ $PARENT_OPERATOR_BALANCE == "0" ]]; then
			if [[ $PARENT_USERNAME == "ec2-user" ]]; then
				echo "Please send 10 Klay to \"${PARENT_OPERATORS[$i]}\" using Baobab faucet (https://baobab.wallet.klaytn.com/access?next=faucet)"
			else
				echo "Please send 10 Klay to \"${PARENT_OPERATORS[$i]}\" in the parent chain (probably a private network)"
			fi
		else
			break
		fi
		read -p "Hit <enter> to continue: " USER_INPUT
	done
done
## Then, parent sender
while :
do
	PARENT_SENDER_BALANCE=$(ssh -i ~/.ssh/servicechain-deploy-key $PARENT_USERNAME@$PARENT_RPC_IP "sudo $PARENT_SERVICE_TYPE attach /var/${PARENT_SERVICE_TYPE}d/data/klay.ipc --exec \"klay.getBalance('$PARENT_SENDER')\"")
	if [[ $PARENT_SENDER_BALANCE == "0" ]]; then
		if [[ $PARENT_USERNAME == "ec2-user" ]]; then
			echo "Please send 100 Klay to \"$PARENT_SENDER\" using Baobab faucet (https://baobab.wallet.klaytn.com/access?next=faucet)"
		else
			echo "Please send 100 Klay to \"$PARENT_SENDER\" in the parent chain (probably a private network)"
		fi
	else
		break
	fi
	read -p "Hit <enter> to continue: " USER_INPUT
done

# NOTE: The child operator does not need to hold KLAY, because the gasPrice is set to 0.
# That is, the child operator can call smart contracts free of charge.
echo "######################################################################"
echo "[WARNING] Make sure that the addresses corresponding to child.key in bridge_info*.json have sufficient funds before value transfer."
echo "          child.key: $CHILD_KEY"
echo -e "          address derived from child.key: $CHILD_SENDER \(100 Klay would be enough\)\n"
echo "######################################################################"

# Prompt the user to deposit some klay to child sender
while :
do
	CHILD_SENDER_BALANCE=$(ssh -i ~/.ssh/servicechain-deploy-key $CHILD_USERNAME@$CHILD_RPC_IP "sudo $CHILD_SERVICE_TYPE attach /var/${CHILD_SERVICE_TYPE}d/data/klay.ipc --exec \"klay.getBalance('$CHILD_SENDER')\"")
	if [[ $CHILD_SENDER_BALANCE == "0" ]]; then
		echo "Please send 100 Klay to \"$CHILD_SENDER\" in the ServiceChain"
	else
		break
	fi
	read -p "Hit <enter> to continue: " USER_INPUT
done

# Test value transfer
## First, install dependencies
pushd value-transfer
cp $PROJ_PATH/klaytn-ansible/bridge_info.json common/bridge_info.json
npm install

## Then, deploy using first bridge
pushd erc20
node erc20-deploy.js

## Get  bridge info
PARENT_BRIDGE=$(jq .contract.parent.bridge transfer_conf.json | tr -d '"')
CHILD_BRIDGE=$(jq .contract.child.bridge transfer_conf.json | tr -d '"')
PARENT_TOKEN=$(jq .contract.parent.token transfer_conf.json | tr -d '"')
CHILD_TOKEN=$(jq .contract.child.token transfer_conf.json | tr -d '"')

## Register bridge and token to each child node
for ((i=0;i<$BRIDGE_COUNT;i++)); do
	SUBBRIDGE_RPC_IP=$(egrep "CHILD$i" $PROJ_PATH/inventory.bridge | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
	ssh -i ~/.ssh/servicechain-deploy-key -q $CHILD_USERNAME@$SUBBRIDGE_RPC_IP "sudo $CHILD_SERVICE_TYPE attach /var/${CHILD_SERVICE_TYPE}d/data/klay.ipc --exec \"subbridge.registerBridge('$CHILD_BRIDGE','$PARENT_BRIDGE')\"; \
		sudo $CHILD_SERVICE_TYPE attach /var/${CHILD_SERVICE_TYPE}d/data/klay.ipc --exec \"subbridge.subscribeBridge('$CHILD_BRIDGE', '$PARENT_BRIDGE')\"; \
		sudo $CHILD_SERVICE_TYPE attach /var/${CHILD_SERVICE_TYPE}d/data/klay.ipc --exec \"subbridge.registerToken('$CHILD_BRIDGE', '$PARENT_BRIDGE', '$CHILD_TOKEN', '$PARENT_TOKEN')\""
done

## Run transfer
node erc20-transfer-1step.js

popd
popd
