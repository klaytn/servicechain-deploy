# ServiceChain deploy tool
A wrapper tool for [klaytn-terraform](https://github.com/klaytn/klaytn-terraform) and [klaytn-ansible](https://github.com/klaytn/klaytn-ansible).
It first runs **klaytn-terraform** to create VMs on AWS,
then runs **klaytn-ansible** to install and deploy klaytn service chain on the created VMs.

## Prerequisites
You need an AWS account. Also, AWS-CLI should be configured correctly in your local environment.
Refer to AWS docs to [install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
and [configure](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) AWS-CLI.

### Configure klaytn-terraform
Before running klaytn-terraform, you need to configure it.
Edit `terraform.tfvars` file under `klaytn-terraform` to fit your needs.
For example, specify the number of ENs and SCNs to be created.
It requires AWS VPC and subnets as inputs, so make sure you have them configured in AWS.
Also, you need an SSH key too.
Refer to [klaytn-terraform](/klaytn-terraform) for more details.

> Currently tested configurations is using 4 SCNs with no EN.

## Run
Use provided scripts to run **klaytn-terraform** then **klaytn-ansible**.
```
$ ./1.run_terraform.sh
$ ./2.run_ansible.sh
BECOME pass: <your password>
```
