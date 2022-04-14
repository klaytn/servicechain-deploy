#!/bin/bash

set -e

# Terminate terraform deployed VMs
pushd klaytn-terraform/service-chain-aws/deploy-4scn
terraform destroy

popd

# Terminate terraform created VPCs if exist
pushd klaytn-terraform/service-chain-aws/create_vpc
terraform destroy

popd
