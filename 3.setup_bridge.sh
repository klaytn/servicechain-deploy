#!/bin/bash

set -e

PROJ_PATH=$(pwd)
pushd klaytn-ansible
cp roles/klaytn_bridge/tutorial/bridge_setup.yml .
ansible-playbook -i $PROJ_PATH/inventory.bridge bridge_setup.yml --ask-become-pass --key-file $HOME/.ssh/servicechain-deploy-key

popd
