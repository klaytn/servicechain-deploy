#!/bin/bash

set -e

# 1. Deploy VMs
pushd klaytn-terraform/service-chain-aws/deploy-4scn
terraform init
terraform apply
## Wait 30 seconds for the deployed VMs to be initialized
echo "Waiting for 30 seconds for the deployed VMs to be initialized..."
sleep 30

# 2. Get IPs of deployed VMs
EN_COUNT=$(terraform state list | grep "aws_eip_association.en" | wc -l)
SCN_COUNT=$(terraform state list | grep "aws_eip_association.scn" | wc -l)
EN_PUBLIC_IP_LIST=($(terraform show -json | jq -r '.values.root_module.resources[] | select(.address | startswith("aws_eip_association.en")) | .values.public_ip'))
SCN_PUBLIC_IP_LIST=($(terraform show -json | jq -r '.values.root_module.resources[] | select(.address | startswith("aws_eip_association.scn")) | .values.public_ip'))
for i in "${!EN_PUBLIC_IP_LIST[@]}"; do
	printf "en[%s]:\t%s\n" "$i" "${EN_PUBLIC_IP_LIST[i]}"
done
for i in "${!SCN_PUBLIC_IP_LIST[@]}"; do
	printf "scn[%s]:\t%s\n" "$i" "${SCN_PUBLIC_IP_LIST[i]}"
done
popd

# 3. Build inventory files for klaytn-ansible
## Create inventory file for klaytn_node role
USERNAME=$(whoami)
cat > inventory.node <<EOF
[controller]
builder ansible_host=localhost ansible_connection=local ansible_user=$USERNAME

EOF
## Add lines like "SCN1 ansible_user=centos ansible_host=1.2.3.4" to inventory for klaytn_node role
echo "[CypressEN]" >> inventory.node
for i in "${!EN_PUBLIC_IP_LIST[@]}"; do
	echo "EN$i ansible_user=ec2-user ansible_host=${EN_PUBLIC_IP_LIST[i]}" >> inventory.node
done
echo "[ServiceChainCN]" >> inventory.node
for i in "${!SCN_PUBLIC_IP_LIST[@]}"; do
	echo "SCN$i ansible_user=centos ansible_host=${SCN_PUBLIC_IP_LIST[i]}" >> inventory.node
done

## Create inventory file for klaytn_bridge role
if [ "$EN_COUNT" -gt 0 ] && [ "$SCN_COUNT" -gt 0 ]; then
	cat > inventory.bridge <<EOF
[controller]
builder ansible_host=localhost ansible_connection=local ansible_user=$USERNAME

[ParentChainNode]
PARENT0 ansible_user=ec2-user ansible_host=${EN_PUBLIC_IP_LIST[0]}

[ChildChainNode]
CHILD0 ansible_user=centos ansible_host=${SCN_PUBLIC_IP_LIST[0]}
EOF
else
	echo "At least one pair of EN and SCN should exist to configure bridge. Skipping..."
fi
