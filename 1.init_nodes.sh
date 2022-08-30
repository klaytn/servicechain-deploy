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

# 1. Deploy VMs
deploy_vms() {
	pushd klaytn-terraform/service-chain-aws/$1
	terraform init
	terraform apply
	## Wait 30 seconds for the deployed VMs to be initialized
	echo "Waiting for 30 seconds for the deployed VMs to be initialized..."
	sleep 30
	popd
}

# 2. Get IPs of deployed VMs
get_ips() {
	pushd klaytn-terraform/service-chain-aws/$1
	CN_COUNT=$(terraform state list | grep "aws_eip_association.cn" | wc -l)
	PN_COUNT=$(terraform state list | grep "aws_eip_association.pn" | wc -l)
	EN_COUNT=$(terraform state list | grep "aws_eip_association.en" | wc -l)
	SCN_COUNT=$(terraform state list | grep "aws_eip_association.scn" | wc -l)
	SPN_COUNT=$(terraform state list | grep "aws_eip_association.spn" | wc -l)
	SEN_COUNT=$(terraform state list | grep "aws_eip_association.sen" | wc -l)
	if [ "$CN_COUNT" -gt 0 ]; then
		CN_PUBLIC_IP_LIST=($(terraform show -json | jq -r '.values.root_module.resources[] | select(.address | startswith("aws_eip_association.cn")) | .values.public_ip'))
	fi
	if [ "$PN_COUNT" -gt 0 ]; then
		PN_PUBLIC_IP_LIST=($(terraform show -json | jq -r '.values.root_module.resources[] | select(.address | startswith("aws_eip_association.pn")) | .values.public_ip'))
	fi
	if [ "$EN_COUNT" -gt 0 ]; then
		EN_PUBLIC_IP_LIST=($(terraform show -json | jq -r '.values.root_module.resources[] | select(.address | startswith("aws_eip_association.en")) | .values.public_ip'))
	fi
	if [ "$SCN_COUNT" -gt 0 ]; then
		SCN_PUBLIC_IP_LIST=($(terraform show -json | jq -r '.values.root_module.resources[] | select(.address | startswith("aws_eip_association.scn")) | .values.public_ip'))
	fi
	if [ "$SPN_COUNT" -gt 0 ]; then
		SPN_PUBLIC_IP_LIST=($(terraform show -json | jq -r '.values.root_module.resources[] | select(.address | startswith("aws_eip_association.spn")) | .values.public_ip'))
	fi
	if [ "$SEN_COUNT" -gt 0 ]; then
		SEN_PUBLIC_IP_LIST=($(terraform show -json | jq -r '.values.root_module.resources[] | select(.address | startswith("aws_eip_association.sen")) | .values.public_ip'))
	fi
	for i in "${!CN_PUBLIC_IP_LIST[@]}"; do
		printf "cn[%s]:\t%s\n" "$i" "${CN_PUBLIC_IP_LIST[i]}"
	done
	for i in "${!PN_PUBLIC_IP_LIST[@]}"; do
		printf "pn[%s]:\t%s\n" "$i" "${PN_PUBLIC_IP_LIST[i]}"
	done
	for i in "${!EN_PUBLIC_IP_LIST[@]}"; do
		printf "en[%s]:\t%s\n" "$i" "${EN_PUBLIC_IP_LIST[i]}"
	done
	for i in "${!SCN_PUBLIC_IP_LIST[@]}"; do
		printf "scn[%s]:\t%s\n" "$i" "${SCN_PUBLIC_IP_LIST[i]}"
	done
	for i in "${!SPN_PUBLIC_IP_LIST[@]}"; do
		printf "spn[%s]:\t%s\n" "$i" "${SPN_PUBLIC_IP_LIST[i]}"
	done
	for i in "${!SEN_PUBLIC_IP_LIST[@]}"; do
		printf "sen[%s]:\t%s\n" "$i" "${SEN_PUBLIC_IP_LIST[i]}"
	done
	popd
}

# 3. Build inventory files for klaytn-ansible
build_inventory() {
	## Create inventory file for klaytn_node role
	USERNAME=$(whoami)
	cat > inventory.node <<EOF
[controller]
builder ansible_host=localhost ansible_connection=local ansible_user=$USERNAME

EOF
	## Add lines like "SCN1 ansible_user=ec2-user ansible_host=1.2.3.4" to inventory for klaytn_node role
	echo "[CypressCN]" >> inventory.node
	for i in "${!CN_PUBLIC_IP_LIST[@]}"; do
		echo "CN$i ansible_user=ec2-user ansible_host=${CN_PUBLIC_IP_LIST[i]}" >> inventory.node
	done
	echo "[CypressPN]" >> inventory.node
	for i in "${!PN_PUBLIC_IP_LIST[@]}"; do
		echo "PN$i ansible_user=ec2-user ansible_host=${PN_PUBLIC_IP_LIST[i]}" >> inventory.node
	done
	echo "[CypressEN]" >> inventory.node
	for i in "${!EN_PUBLIC_IP_LIST[@]}"; do
		echo "EN$i ansible_user=ec2-user ansible_host=${EN_PUBLIC_IP_LIST[i]}" >> inventory.node
	done
	echo "[ServiceChainCN]" >> inventory.node
	for i in "${!SCN_PUBLIC_IP_LIST[@]}"; do
		echo "SCN$i ansible_user=ec2-user ansible_host=${SCN_PUBLIC_IP_LIST[i]}" >> inventory.node
	done
	echo "[ServiceChainPN]" >> inventory.node
	for i in "${!SPN_PUBLIC_IP_LIST[@]}"; do
		echo "SPN$i ansible_user=ec2-user ansible_host=${SPN_PUBLIC_IP_LIST[i]}" >> inventory.node
	done
	echo "[ServiceChainEN]" >> inventory.node
	for i in "${!SEN_PUBLIC_IP_LIST[@]}"; do
		echo "SEN$i ansible_user=ec2-user ansible_host=${SEN_PUBLIC_IP_LIST[i]}" >> inventory.node
	done

	## Create inventory file for klaytn_bridge role
	## If there are SENs, use SEN for bridge instead of SCN
	if [ "$EN_COUNT" -gt 0 ] && [ "$SEN_COUNT" -gt 0 ]; then
		BRIDGE_COUNT=$((EN_COUNT > SCN_COUNT ? SCN_COUNT : EN_COUNT))
		cat > inventory.bridge <<EOF
[controller]
builder ansible_host=localhost ansible_connection=local ansible_user=$USERNAME

EOF
		echo "[ParentBridgeNode]" >> inventory.bridge
		for ((i=0;i<BRIDGE_COUNT;i++)); do
			echo "PARENT$i ansible_user=ec2-user ansible_host=${EN_PUBLIC_IP_LIST[i]} parent_service_type=kend" >> inventory.bridge
		done
		echo "[ChildBridgeNode]" >> inventory.bridge
		for ((i=0;i<BRIDGE_COUNT;i++)); do
			echo "CHILD$i ansible_user=ec2-user ansible_host=${SEN_PUBLIC_IP_LIST[i]} child_service_type=ksend" >> inventory.bridge
		done
	## If there is no SEN, use SCN for bridge
	elif [ "$EN_COUNT" -gt 0 ] && [ "$SCN_COUNT" -gt 0 ]; then
		BRIDGE_COUNT=$((EN_COUNT > SCN_COUNT ? SCN_COUNT : EN_COUNT))
		cat > inventory.bridge <<EOF
[controller]
builder ansible_host=localhost ansible_connection=local ansible_user=$USERNAME

EOF
		echo "[ParentBridgeNode]" >> inventory.bridge
		for ((i=0;i<BRIDGE_COUNT;i++)); do
			echo "PARENT$i ansible_user=ec2-user ansible_host=${EN_PUBLIC_IP_LIST[i]} parent_service_type=kend" >> inventory.bridge
		done
		echo "[ChildBridgeNode]" >> inventory.bridge
		for ((i=0;i<BRIDGE_COUNT;i++)); do
			echo "CHILD$i ansible_user=ec2-user ansible_host=${SCN_PUBLIC_IP_LIST[i]} child_service_type=kscnd" >> inventory.bridge
		done
	else
		echo "At least one pair of EN and SCN should exist to configure bridge. Skipping..."
	fi
}

if [ $# -eq 0 ]; then
	usage
fi

target=$1
shift

case "$target" in
        en-4scn)
		deploy_vms deploy-4scn
		get_ips deploy-4scn
                ;;
        en-L2)
		deploy_vms deploy-scn-spn-sen
		get_ips deploy-scn-spn-sen
                ;;
        L1-L2)
		deploy_vms deploy-L1-L2
		get_ips deploy-L1-L2
                ;;
	L2)
		deploy_vms deploy-multi_layer-servicechain
		get_ips deploy-multi_layer-servicechain
		;;
        *)
                usage
                ;;
esac

build_inventory
