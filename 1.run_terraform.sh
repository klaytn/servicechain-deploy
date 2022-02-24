#!/bin/bash

# 1. Deploy VMs
# TODO: Currently there is a typo in klaytn-terraform, so below 'serivce' is intended.
pushd klaytn-terraform/serivce-chain-aws
terraform init
terraform apply

# 2. Get IPs of deployed VMs
SCN_COUNT=$(terraform state list | grep "aws_eip_association.scn" | wc -l)
PUBLIC_IP_LIST=($(terraform show -json | jq -r '.values.root_module.resources[] | select(.address | startswith("aws_eip_association")) | .values.public_ip'))
PRIVATE_IP_LIST=($(terraform show -json | jq -r '.values.root_module.resources[] | select(.address | startswith("aws_eip_association")) | .values.private_ip_address'))
for i in "${!PUBLIC_IP_LIST[@]}"; do
	printf "scn[%s]:\t%s\n" "$i" "${PUBLIC_IP_LIST[i]}"
done
popd

# 3. Build inventory file for klaytn-ansible
USERNAME=$(whoami)
cat > inventory <<EOF
[controller]
builder ansible_host=localhost ansible_connection=local ansible_user=$USERNAME

[ServiceChainCN]
EOF

## Add lines like "SCN1 ansible_user=centos ansible_host=13.125.23.130"
for i in "${!PUBLIC_IP_LIST[@]}"; do
	echo "SCN$i ansible_user=centos ansible_host=${PUBLIC_IP_LIST[i]} klaytn_p2p_host=${PRIVATE_IP_LIST[i]}" >> inventory
done

