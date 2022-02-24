#!/bin/bash

PROJ_PATH=$(pwd)
pushd klaytn-ansible
cp roles/klaytn_node/tutorial/service_chain_SCN_setup.yml .
ansible-playbook -i $PROJ_PATH/inventory service_chain_SCN_setup.yml --ask-become-pass

popd
