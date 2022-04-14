#!/bin/bash

set -e

PROJ_PATH=$(pwd)
pushd klaytn-ansible
cp roles/klaytn_node/tutorial/service_chain_SCN_setup.yml .
ansible-playbook -i $PROJ_PATH/inventory.node service_chain_SCN_setup.yml --ask-become-pass --key-file $HOME/.ssh/servicechain-deploy-key

popd
