# ServiceChain deploy tool
ServiceChain deploy tool provides easier way to deploy ServiceChain on Klaytn.
The ServiceChain deployed by this tool follows the architecture explained in the [Klaytn Docs](https://docs.klaytn.com/node/service-chain/getting-started).

This repository uses [klaytn-terraform](https://github.com/klaytn/klaytn-terraform) and [klaytn-ansible](https://github.com/klaytn/klaytn-ansible).
Also, to test value transfer between chains, this repository uses [servicechain-value-transfer-examples](https://github.com/klaytn/servicechain-value-transfer-examples).

## Table of contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Configure](#configure)
- [Run](#run)
- [Terminate](#terminate)

## Overview
This tool provides an easier way to follow the steps described in the
[Klaytn docs](https://docs.klaytn.com/node/service-chain/getting-started/4nodes-setup-guide).
You do not have to repeat same jobs or copy files manually,
instead you can use provided scripts.

**IMPORTANT** This tool is for test purpose.
Using this tool without modification in production is discorouged.

### Modules
1. klaytn-terraform

   The [klaytn-terraform](./klaytn-terraform) module runs `terraform` to deploy new VMs.
   Currently supported cloud platform for ServiceChain deploy tool is AWS,
   however **klaytn-terraform** supports Azure.
   To configure a new Endpoint Node (EN) for the Klaytn mainnet(Cypress)/testnet(Baobab),
   **klaytn-ansible** uses belowe AMIs.
   - AWS AMI for Cypress EN: TBU
   - AWS AMI for Baobab EN: TBU

   The provided script `1.run_terraform.sh` performs following tasks:
   - Run **klaytn-terraform** to deploy VMs in AWS
   - Fetch IPs of the deployed VMs to create the `inventory` file for **klaytn-ansible**.

2. klaytn-ansible

   The [klaytn-ansible](/klaytn-ansible) module runs `ansible` to install and configure
   Klaytn nodes in the newly deployed VMs.
   The **klaytn-ansible** has two roles:
   - `klaytn_node`:

      To configure newly deployed VMs, the `klaytn_node` role installs required packages,
      creates configuration files on the newly created VMs.
   - `klaytn_bridge`:

      To deloy bridge between two chains (e.g., Baobab testnet <-> ServiceChain),
      the `klaytn_bridge` role add configuration for bridge to a pair of nodes;
      one on the parent chain and the other on the child chain.
      Also, the `klaytn_bridge` role generates `bridge_info.json` that contains
      the information for newly deployed bridge and will be used to test value transfer
      by **value-transfer**.

3. value-transfer

   The [value-transfer](/value-transfer) module runs example scripts to test
   value transfer between two chains. It provides examples of value transfer for the following assets:
   - Klay
   - ERC20
   - ERC721
   - KIP7
   - KIP17

   **IMPORTANT** Before testing value transfer, please make sure that the associated accounts
   (e.g., bridge operators) hold enough Klays.

## Prerequisites
1. AWS account and AWS-CLI

    You need an AWS account. Also, AWS-CLI should be configured correctly in your local environment.
    Refer to AWS docs to [install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
    and [configure](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) AWS-CLI.

2. terraform

    ServiceChain deploy tool uses terraform to create VMs on AWS.
    Refer to the [installation guide](https://learn.hashicorp.com/tutorials/terraform/install-cli).

3. ansible

    ServiceChain deploy tool uses ansible to install and deploy Klaytn ServiceChain on the created VMs.
    Refer to the [installation guide](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html).

4. Node.js

    ServiceChain deploy tool uses [value transfer examples](/value-transfer)
    to test value transfer between the parent chain and child chain.
    Those examples use caver-js, which requires Node.js 12 and 14.
    Refer to the [installation guide](https://nodejs.org/en/download/package-manager/) to install Node.js.
    If you are already using a different version of Node.js, use the Node Version Manager ([NVM](https://github.com/nvm-sh/nvm))
    to install a Node.js with the version supported by caver-js along with the existing Node.js.

## Configure
Before running **klaytn-terraform**, you need to configure it.

1. Create AWS VPC and subnets

    **klaytn-terraform** requires AWS VPC and subnets as inputs, so make sure you have them configured in AWS.
    Refer to [AWS docs](https://docs.aws.amazon.com/vpc/latest/userguide/working-with-vpcs.html) to create a VPC and a subnet.

2. Create an SSH key if you don't have one

    **klaytn-terraform** requires an SSH key in order to make created VMs accessible by **klaytn-ansible**.
    So you need an SSH key too.

3. Edit `terraform.tfvars`

    Edit `terraform.tfvars` file under `klaytn-terraform` to fit your needs.
    For example, specify the number of ENs and SCNs to be created.

## Run
Use provided scripts to run **klaytn-terraform**, **klaytn-ansible**, then test value transfer examples.

Currently supported cases are:
- `run-en-4scn.sh`: Join Baobab testnet (deploy new EN) and deploy ServiceChain (4 SCNs)
- `TBU`: Create a private Klaytn network (1 CN, 1 PN, 1 EN) and deploy ServiceChain (4 SCNs)
- `TBU`: Create a private Klaytn network (1 CN, 1 PN, 1 EN) and deploy ServiceChain (4 SCNs, 4 SPNs, 4 SENs)
- `TBU`: Deploy ServiceChain (4 SCNs) and bridge to an existing node (on either Baobab or ServiceChain)

### Prerequisite - Prepare `terraform.tfvars`

Create `terraform.tfvars` under the directory `klaytn-terraform/service-chain-aws/deploy-4scn`.
Below is an example configuration for `terraform.tfvars`.
You should fill in empty contents to fit your setup.

**IMPORTANT** You should have an existing AWS account and AWS-CLI configured in your local environment.
Also, you need an existing AWS VPC and subnet. Please create them if you haven't.
See [configure](#configure) for brief instructions.

```
$ cat > klaytn-terraform/service-chain-aws/deploy-4scn/terraform.tfvars <<EOF
# Prefix for the created VMs. e.g., "sawyer-test"
name = ""
# The VPC's ID. e.g., "vpc-0123456789abcdef"
# If you haven't created any VPC, you have to create one.
vpc_id = ""
# The region for the pre-configured VPC. e.g., "ap-northeast-2"
region = ""
# The subnet ID for ENs, e.g., "subnet-0123456789abcdef"
# If you haven't created any subnet, you have to create one.
en_subnet_ids = [""]
# The subnet ID for SCNs, e.g., "subnet-0123456789abcdef"
# If you haven't created any subnet, you have to create one.
scn_subnet_ids = [""]
# The IP address (should be the public IP address of your host)
# to allow SSH connections to the created VMs. e.g., "1.2.3.4/32"
ssh_client_ips = [""]
# The pubkey for SSH connection, e.g., "ssh-ed25519 AAAA...JB sawyer-ssh-key"
ssh_pub_key = ""
# The name for the SSH keypair, e.g., "sawyer-ssh-key"
aws_key_pair_name = ""
# The name for newly created security group, e.g., "sawyer-test"
security_group = ""

# Provide appropriate numbers to fit your need
scn_instance_count = "4"
en_instance_count = "1"
EOF
```

**IMPORTANT** Make sure to destroy created resources before testing another case.

### Case A. Join Baobab testnet (deploy new EN) and deploy ServiceChain (4 SCNs)

Make sure you have correctly configured `klaytn-terraform/service-chain-aws/deploy-4scn/terraform.tfvars`
in the previous step.
Then, run provided script `run-en-4scn.sh`.

```
$ ./run-en-4scn.sh

...

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

...
BECOME pass: <your password>
```

The script performs the following tasks:
1. Check configuration file for **klaytn-terraform** (`terraform.tfvars`) exists
2. Run **klaytn-terraform**
3. Run **klaytn-ansible** with `klaytn_node` role
4. Wait until the newly created EN sync is done.
5. Run **klaytn-ansible** with `klaytn_bridge` role
6. Prompt the user to deposit enough Klay to associated accounts to test value transfer
7. Run **value-transfer** to test value transfer for ERC20 tokens.

If everything went well, you should be able to see alice's balance
being increased in the value transfer test like below:

```
------------------------- erc20-transfer-1step START -------------------------
alice balance: 0
requestValueTransfer..
alice balance: 100
------------------------- erc20-transfer-1step END -------------------------
------------------------- erc20-transfer-2step START -------------------------
alice balance: 100
requestValueTransfer..
alice balance: 200
------------------------- erc20-transfer-2step END -------------------------
```

### Case B. Create a private Klaytn network (1 CN, 1 PN, 1 EN) and deploy ServiceChain (4 SCNs)
TBD
### Case C. Create a private Klaytn network (1 CN, 1 PN, 1 EN) and deploy ServiceChain (4 SCNs, 4 SPNs, 4 SENs)
TBD
### Case D. Deploy ServiceChain (4 SCNs) and bridge to an existing node (on either Baobab or ServiceChain)
TBD

## Terminate

After you have successfully deployed and tested Klaytn ServiceChain,
you can destroy all created resources using the provided script.

```
$ ./5.terminate.sh

...

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

...

Destroy complete! Resources: 35 destroyed.
```

