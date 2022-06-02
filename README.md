# ServiceChain deploy tool
ServiceChain deploy tool provides easier way to deploy ServiceChain on Klaytn.
The ServiceChain deployed by this tool follows the architecture explained in the [Klaytn Docs](https://docs.klaytn.com/node/service-chain/getting-started).

This repository uses [klaytn-terraform](https://github.com/klaytn/klaytn-terraform) and [klaytn-ansible](https://github.com/klaytn/klaytn-ansible).
Also, to test value transfer between chains, this repository uses [servicechain-value-transfer-examples](https://github.com/klaytn/servicechain-value-transfer-examples).

## Table of contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Getting Started](#gettingstarted)
- [Configure](#configure)
- [Run](#run)
- [Terminate](#terminate)

## Overview
This tool provides an easier way to follow the steps described in the
[Klaytn docs](https://docs.klaytn.com/node/service-chain/getting-started/4nodes-setup-guide).
You do not have to repeat same jobs or copy files manually,
instead you can use provided scripts.

**IMPORTANT** This tool is for test purpose.
Using this tool without modification in production is strongly discorouged.

### Modules
1. klaytn-terraform

   The [klaytn-terraform](https://github.com/klaytn/klaytn-terraform) module runs `terraform` to deploy new VMs.
   Currently supported cloud platform for ServiceChain deploy tool is AWS,
   however **klaytn-terraform** supports Azure, too.
   To configure a new Endpoint Node (EN) for the Klaytn mainnet(Cypress)/testnet(Baobab),
   **klaytn-terraform** uses below AMIs.
   - AWS AMI for Cypress EN: `baobab-clean-en-ami-<date created>`
   - AWS AMI for Baobab EN: `cypress-clean-en-ami-<date created>`

   The provided script `1.run_terraform.sh` performs following tasks:
   - Run **klaytn-terraform** to deploy VMs in AWS
   - Fetch IPs of the deployed VMs to create the `inventory` file for **klaytn-ansible**.

2. klaytn-ansible

   The [klaytn-ansible](https://github.com/klaytn/klaytn-ansible) module runs `ansible` to install and configure
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

   The [value-transfer](https://github.com/klaytn/servicechain-value-transfer-examples) module runs example scripts to test
   value transfer between two chains. It provides examples of value transfer for the following assets:
   - Klay
   - ERC20
   - ERC721
   - KIP7
   - KIP17

   **IMPORTANT** Before testing value transfer, please make sure that the associated accounts
   (e.g., bridge operators) hold enough Klays.

## Prerequisites
1. AWS account and AWS-CLI, and subscription for CentOS AMI

    You need an AWS account. Also, AWS-CLI should be configured correctly in your local environment.
    Refer to AWS docs to [install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
    and [configure](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) AWS-CLI.
    Furthermore, you need to subscribe [CentOS AMI](https://aws.amazon.com/marketplace/pp/Centosorg-CentOS-7-x8664-with-Updates-HVM/B00O7WM7QW#pdp-usage)
    in order to create CentOS VMs.

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

5. `jq`, `curl`, `tr`, `sed`
    These binaries are commonly installed in most systems, however if your host does not have one, please install required package.

## Getting Started
TBU
Probably the most simple architecture would be 1 SCN + 4 SCN.

## Configure
Before running **klaytn-terraform**, you need to configure it.
You can use `0.prepare.sh` to configure with default settings.

These are the actions performed by `0.prepare.sh` and what you need to do if you want to configure on your own,
without using `0.prepare.sh`.

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
Use provided scripts to run **klaytn-terraform** and **klaytn-ansible**.

Currently supported cases are:
- `run-en-4scn.sh`: Join Baobab testnet (deploy new EN) and deploy ServiceChain (4 SCNs)
- `run-en-L2.sh`: Join Baobab testnet (deploy new EN) and deploy ServiceChain (4 SCNs, 2 SPNs, 2 SENs)
- `run-L1-L2.sh`: Create a private Klaytn network (1 CN, 1 PN, 1 EN) and deploy ServiceChain (4 SCNs, 2 SPNs, 2 SENs)

After you have successfully deployed and configured Klaytn and ServiceChain, you can test value transfer
using the provided script `test_value_transfer.sh`. See [Test value transfer](#test-value-transfer).

### Testing each cases

**IMPORTANT** Make sure to destroy created resources before testing another case.

You can test each cases using provided scripts. The scripts will often require your confirmation on performing some actions.

For example,

```
$ ./run-en-4scn.sh
...

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

...
```

The scripts perform the following tasks:
1. Check configuration file for **klaytn-terraform** (`terraform.tfvars`) exists
2. Run **klaytn-terraform** to create new VMs
3. Run **klaytn-ansible** with `klaytn_node` role to install and configure Klaytn in created VMs
4. If deployed a new Baobab EN, wait until the chaindata sync is done (e.g., `run-en-4scn.sh`, `run-en-L2.sh`)
5. Run **klaytn-ansible** with `klaytn_bridge` role to configure bridge

### Test value transfer

After you have successfully deployed and configured Klaytn and ServiceChain using the provided script,
you can test value transfer with the script `test_value_transfer.sh`.

```
$ ./test_value_transfer.sh
```
The script performs the following actions:
1. Prompt the user to deposit enough Klay to associated accounts to test value transfer
2. Deploy ERC20 token and associated token bridge(s) using **value-transfer**.
3. Transfer ERC20 between parent and child chains using **value-transfer**.

If everything went well, you should be able to see alice's balance
being increased in the value transfer test like below:

```
------------------------- erc20-transfer-1step START -------------------------
alice balance: 0
requestValueTransfer..
alice balance: 100
------------------------- erc20-transfer-1step END -------------------------
```

## Terminate

After you have successfully deployed and tested Klaytn ServiceChain,
you can destroy all created resources using the provided script.

```
$ ./4.terminate.sh

...

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

...

Destroy complete! Resources: 35 destroyed.
```

