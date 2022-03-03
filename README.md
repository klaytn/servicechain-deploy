# Service Chain deploy tool
Service Chain deploy tool provides easier way to deploy Service Chain on Klaytn.
The Service Chain deployed by this tool follows the architecture explained in the [Klaytn Docs](https://docs.klaytn.com/node/service-chain/getting-started).

This repository has two submodules [klaytn-terraform](https://github.com/klaytn/klaytn-terraform) and [klaytn-ansible](https://github.com/klaytn/klaytn-ansible).

## Table of contents

- [Why do you use Service Chain deploy tool?](#why-do-you-use-service-chain-deploy-tool)
- [Prerequisites](#prerequisites)
- [Configure](#configure)
- [Run](#run)
- [Value Transfer](#value-transfer)

## Why do you use Service Chain deploy tool?
This tool provides an easier way to follow the steps described in the
[Klaytn docs](https://docs.klaytn.com/node/service-chain/getting-started/4nodes-setup-guide).
You do not have to repeat same jobs or copy files manually,
instead you can use provided scripts.

## Prerequisites
1. AWS account and AWS-CLI

    You need an AWS account. Also, AWS-CLI should be configured correctly in your local environment.
    Refer to AWS docs to [install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
    and [configure](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) AWS-CLI.

2. terraform

    Service Chain deploy tool uses terraform to create VMs on AWS.
    Refer to the [installation guide](https://learn.hashicorp.com/tutorials/terraform/install-cli).

3. ansible

    Service Chain deploy tool uses ansible to install and deploy Klaytn Service Chain on the created VMs.
    Refer to the [installation guide](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html).

## Configure
Before running **klaytn-terraform**, you need to configure it.

1. Edit `terraform.tfvars`

    Edit `terraform.tfvars` file under `klaytn-terraform` to fit your needs.
    For example, specify the number of ENs and SCNs to be created.

2. Create AWS VPC and subnets

    **klaytn-terraform** requires AWS VPC and subnets as inputs, so make sure you have them configured in AWS.
    Refer to [AWS docs](https://docs.aws.amazon.com/vpc/latest/userguide/working-with-vpcs.html) to create a VPC and a subnet.

3. Create an SSH key

    **klaytn-terraform** requires an SSH key in order to make created VMs accessible by **klaytn-ansible**.
    So you need an SSH key too.

Refer to [klaytn-terraform](/klaytn-terraform) for more details.

> Currently tested configurations is using 4 SCNs with no EN. That is,
>
>     scn_instance_count = "4"
>     en_instance_count = "0"
> in `terraform.tfvars`.

## Run
Use provided scripts to run **klaytn-terraform** then **klaytn-ansible**.
```
$ ./1.run_terraform.sh
$ ./2.run_ansible.sh
BECOME pass: <your password>
```

## Value transfer
TBD

Add value transfer script.
