#!/bin/bash

set -e

# Terminate terraform deployed VMs
pushd klaytn-terraform/service-chain-aws/deploy-4scn
terraform destroy

popd
