# Branch name will be changed

We will change the `master` branch to `main` at Dec 15, 2022.
After change branch policy, please check your local or forked repository settings.

# ServiceChain deploy tool
ServiceChain deploy tool provides easier way to deploy ServiceChain on Klaytn.
The ServiceChain deployed by this tool follows the architecture explained in the [Klaytn Docs](https://docs.klaytn.com/node/service-chain/getting-started).

This repository uses [klaytn-terraform](https://github.com/klaytn/klaytn-terraform) and [klaytn-ansible](https://github.com/klaytn/klaytn-ansible).
Also, to test value transfer between chains, this repository uses [servicechain-value-transfer-examples](https://github.com/klaytn/servicechain-value-transfer-examples).

## Table of contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
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

   The provided script `1.init_nodes.sh` performs following tasks:
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

5. `jq`, `curl`, `tr`, `sed`
    These binaries are commonly installed in most systems, however if your host does not have one, please install required package.

## Getting Started
This section gives you a brief introduction through each steps that servicechain-deploy tool takes.
For the getting started example, we will deploy a private network (L1, parent chain) comprising of 1 CN + 1 EN and its ServiceChain (L2, child chain) with 4 SCNs.

The getting started example consists of the following steps.
1. Create VPC, subnet and SSH key
2. Edit `terraform.tfvars`
3. Deploy fresh VMs in AWS
4. Install and configure Klaytn in deployed VMs
5. Configure bridge between parent and child chains
6. Test value transfer between chains
7. Terminate deployed resources

### 1. Create VPC, subnet and SSH key

First, create a VPC and subnet in AWS.

```
$ cd klaytn-terraform/service-chain-aws/create-vpc
$ terraform init && terraform apply
# below command takes you back to the project root
$ cd ../../..
```

The IDs of deployed VPC and subnet will be shown. Those IDs will be used in the next step.

Also, create an SSH key.

```
$ ssh-keygen -b 2048 -t rsa -f ~/.ssh/servicechain-deploy-key -N ""
$ cat ~/.ssh/servicechain-deploy-key.pub
ssh-rsa .......
```

This SSH key will be used for connecting to deployed instances.
The public key of this SSH key (the content of the file `~/.ssh/servicechain-deploy-key.pub`) is required in the next step.

### 2. Edit `terraform.tfvars`

Then, create or edit `klaytn-terraform/service-chain-aws/deploy-L1-L2/terraform.tfvars` with the following content.

```
$ vi klaytn-terraform/service-chain-aws/deploy-L1-L2/terraform.tfvars
name="servicechain-deploy"
region="ap-northeast-2"
vpc_id="$VPC_ID"
cn_subnet_ids = ["$SUBNET_ID"]
pn_subnet_ids = ["$SUBNET_ID"]
en_subnet_ids = ["$SUBNET_ID"]
scn_subnet_ids = ["$SUBNET_ID"]
spn_subnet_ids = ["$SUBNET_ID"]
sen_subnet_ids = ["$SUBNET_ID"]
grafana_subnet_ids = ["$SUBNET_ID"]
cn_instance_count = "1"
pn_instance_count = "0"
en_instance_count = "1"
scn_instance_count = "1"
spn_instance_count = "0"
sen_instance_count = "0"
grafana_instance_count = "0"
ssh_client_ips = ["$MY_IP/32"]
ssh_pub_key = "$SSH_PUBKEY"
aws_key_pair_name = "servicechain-deploy"
```
Please replace `VPC_ID` and `SUBNET_ID` with the IDs printed in the previous step.
Also, replace `MY_IP` with the IP address of your machine.
Lastly, replace `SSH_PUBKEY` with the public key of the SSH key created in the previous step.

### 3. Deploy fresh VMs in AWS

Now, you can deploy new VMs for Klaytn nodes in AWS.

```
$ cd klaytn-terraform/service-chain-aws/deploy-L1-L2
$ terraform init && terraform apply
# below command takes you back to the project root
$ cd ../../..
```

The IP addresses of deployed VMs will be shown. Those IP addresses will be used in the next step (the public IP, not the priavte IP).

### 4. Install and configure Klaytn in deployed VMs

Then, create or edit `klaytn-ansible/roles/klaytn_node/inventory` with the following content.

```
$ vi klaytn-ansible/roles/klaytn_node/inventory
[ServiceChainCN]
SCN0  ansible_host=10.11.12.13  ansible_user=ec2-user
SCN1  ansible_host=10.11.12.14  ansible_user=ec2-user
SCN2  ansible_host=10.11.12.15  ansible_user=ec2-user
SCN3  ansible_host=10.11.12.16  ansible_user=ec2-user

[CypressCN]
CN0  ansible_host=1.2.3.4  ansible_user=ec2-user

[CypressEN]
EN0  ansbile_host=5.6.7.8  ansible_user=ec2-user

[controller]
builder ansible_host=localhost ansible_connection=local ansible_user=YOUR_USER
```

Be sure to replace `ansible_host` to the IP addresses of deployed VMs.
Also, replace `YOUR_USER` with the username of your machine.

Now, run ansible playbook to install and configure Klaytn nodes.

```
$ cd klaytn-ansible
$ cp roles/klaytn_node/tutorial/service_chain_SCN_setup.yml .
$ ansible-playbook -i roles/klaytn_node/inventory service_chain_SCN_setup.yml --key-file ~/.ssh/servicechain-deploy-key
# below command takes you back to the project root
$ cd ..
```

### 5. Configure bridge between parent and child chains

Create or edit `klaytn-ansible/roles/klaytn_bridge/inventory` with the following content.

```
$ vi klaytn-ansible/roles/klaytn_bridge/inventory
[ParentBridgeNode]
PARENT0 ansible_host=1.2.3.4 ansible_user=ec2-user

[ChildBridgeNode]
CHILD0 ansible_host=5.6.7.8 ansible_user=ec2-user

[controller]
builder ansible_host=localhost ansible_connection=local ansible_user=YOUR_USER
```

Be sure to replace `ansible_host` to the IP addresses of deployed VMs.
Also, replace `YOUR_USER` with the username of your machine.

To configure bridge between parent and child chains, a pair of nodes are required; one from parent and the other from child chain.
We are currently deploying the parent chain with 1 CN + 1 EN, and its child chain with 4 SCNs.
So the bridge should be configured by paring the EN and one of the SCNs.
You can choose any SCN you want; however we will use the first SCN in this example.
As a result, replace `ansible_host` of the host `PARENT0` with the IP address of the EN,
and replace `ansible_host` of the host `CHILD0` with the IP address of the first SCN.

Then, run ansible to configure bridge between parent and child chains.

```
$ cd klaytn-ansible
$ cp roles/klaytn_bridge/tutorial/bridge_setup.yml .
$ ansible_playbook -i roles/klaytn_bridge/inventory bridge_setup.yml --key-file ~/.ssh/servicechain-deploy-key
# below command takes you back to the project root
$ cd ..
```

### 6. Test value transfer between two chains

Testing value trasfer requires the following steps.
1. Get parent and child bridge operators
2. Create `bridge_info.json`
3. Deploy and register bridge contracts (and token contracts in some cases)
4. Test value transfer

#### 6.1 Get parent and child bridge operators

First, SSH to the SCN instance and connect to the Javascript console.

```
$ ssh ec2-user@10.11.12.13
[ec2-user@10.5.6.7 ~] $ sudo kscn attach /var/kscnd/data/klay.ipc
Welcome to the Klaytn JavaScript console!

instance: Klaytn/v1.8.4/linux-amd64/go1.18
 datadir: /var/kend/data
 modules: admin:1.0 debug:1.0 eth:1.0 governance:1.0 istanbul:1.0 klay:1.0 mainbridge:1.0 net:1.0 personal:1.0 rpc:1.0 txpool:1.0 web3:1.0

> subbridge.parentOperator
"0xaabbccdd"
> subbridge.childOperator
"0xaaccddbb"
```


#### 6.2 Create `bridge_info.json`

Create or edit `value-transfer/common/bridge_info.json` with the following content.

```
$ vi value-transfer/common/bridge_info.json
{
    "sender": {
        "child": {
            "key": "0xc544b44c1c58955af516c1f2ff17f8fd522604f1ea6b64db79e067343ed5e307"
        },
        "parent": {
            "key": "0x4b07ca7412ad2bb0e62db30369b9f08a8724fb81fce4b3b1af23800233074fbf"
        }
    },
    "url": {
        "child": "http://$SCN_IP:8551",
        "parent": "http://$EN_IP:8551"
    },
    "bridges": [
        {
            "child" : {
                "operator": "$CHILD_OPERATOR"
            },
            "parent" : {
                "operator": "$PARENT_OPERATOR"
            }
        }
    ]
}
```

Be sure to replace `EN_IP` and `SCN_IP` with the IP addresses of EN and SCN.
Also, replace `PARENT_OPERATOR` and `CHILD_OPERATOR` with the parent and child bridge operators discovered in the previous step.

#### 6.3 Deploy and register bridge contracts

Deploy and register bridge contracts.
```
$ cd value-transfer/erc20
$ npm install
$ node erc20-deploy.js
------------------------- erc20-deploy START -------------------------
info.bridge: 0x88413F043CC07942DC1dF642FC3d3FaFb682858c
info.token: 0xF2F70FA143CBC730aD389A2609E95Fb78D300826
info.bridge: 0x5eF4E943AA9738B91107e8A94e3fe7b0Bd4F969f
info.token: 0x67dB12BD7325f4053E1992b5E5114cf113894De4
############################################################################
Run below 3 commands in the Javascript console of all child bridge nodes (1 nodes total)
subbridge.registerBridge("0x88413F043CC07942DC1dF642FC3d3FaFb682858c", "0x5eF4E943AA9738B91107e8A94e3fe7b0Bd4F969f")
subbridge.subscribeBridge("0x88413F043CC07942DC1dF642FC3d3FaFb682858c", "0x5eF4E943AA9738B91107e8A94e3fe7b0Bd4F969f")
subbridge.registerToken("0x88413F043CC07942DC1dF642FC3d3FaFb682858c", "0x5eF4E943AA9738B91107e8A94e3fe7b0Bd4F969f", "0xF2F70FA143CBC730aD389A2609E95Fb78D300826", "0x67dB12BD7325f4053E1992b5E5114cf113894De4")
############################################################################
------------------------- erc20-deploy END -------------------------
```

The last command will print some commands that should be run in the Javascript console of the child chain.
SSH to the bridged SCN instance then run printed commands in the Javascript console.
```
$ ssh ec2-user@10.1.2.3
[ec2-user@10.1.2.3 ~]$ sudo kscn attach /var/kscnd/data/klay.ipc
Welcome to the Klaytn JavaScript console!

instance: Klaytn/v1.8.4/linux-amd64/go1.18
 datadir: /var/kend/data
 modules: admin:1.0 debug:1.0 eth:1.0 governance:1.0 istanbul:1.0 klay:1.0 mainbridge:1.0 net:1.0 personal:1.0 rpc:1.0 txpool:1.0 web3:1.0

> subbridge.registerBridge(...)
null
> subbridge.subscribeBridge(...)
null
> subbridge.registerToken(...)
null
```

#### 6.4 Test value transfer

Now, you can finally test value transfer.
```
# Make sure you're in the directory value-transfer/erc20
$ node erc20-transfer-1step.js
------------------------- erc20-transfer-1step START -------------------------
alice balance: 0
requestValueTransfer..
alice balance: 100
------------------------- erc20-transfer-1step END -------------------------
```

**NOTE** In order to test KLAY trasnfer, you should send some KLAYs to each sender accounts (the account derived from the parent and child sender keys).

### Terminate deployed resources

You have deployed 2 terraform projects; one for VPC and subnet and the other for Klaytn node VMs.

First, destroy Klaytn node VMs.

```
$ cd klaytn-terraform/service-chain-aws/create-vpc
$ terraform destroy
# below command takes you back to the project root
$ cd ../../..
```

Then destroy VPC and subnet.

```
$ cd klaytn-terraform/service-chain-aws/create-vpc
$ terraform destroy
# below command takes you back to the project root
$ cd ../../..
```

### Wrapping up

There are more usecases, other than deploying 1 CN + 1 EN + 4 SCNs.
The other usecases are covered by preset scripts, so you don't have go through all the steps shown above.
All you have to do is run provided scripts, with minial interaction.

Refer to [Run](#run) for more details.

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

**IMPORTANT** Note that this script will destroy all resources created by servicechain-deploy.

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

