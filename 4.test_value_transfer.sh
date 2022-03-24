#!/bin/bash

set -e

PROJ_PATH=$(pwd)
pushd value-transfer
cp $PROJ_PATH/klaytn-ansible/bridge_info.json common/
npm install
pushd erc20
./erc20-deploy-and-test-transfer.sh

popd
popd
