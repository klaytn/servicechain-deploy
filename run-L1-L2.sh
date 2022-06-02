#!/bin/bash

PROJ_PATH=$(pwd)
set -e

# Prepare terraform.tfvars
./0.prepare.sh L1-L2

# Run terraform to initialize new VMs for nodes
./1.init_nodes.sh L1-L2

# Run ansible klaytn_node
./2.setup_nodes.sh

# Run ansible klaytn_bridge
./3.setup_bridge.sh
