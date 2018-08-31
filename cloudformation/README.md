# Cloudformation Templates

This repository hosts Cloudformation templates and helpers to deploy resources as they have been developed and deployed to my lab.

## Templates

### environment.yaml

Deploys a parent stack, which deploys the child stacks identified below. Results in a usable VPC with bastion host.

### vpc.yaml

Deploys a simple VPC to put other resources into. Features include:

  * Two Availability Zones for HA design
  * DNS enabled
  * VPC hostname resolution
  * Internet Gateway
  * NAT Gateway in each AZ with Elastic IP addresses
  * Three-tier network architecture (three subnets in each AZ):
    + Public (route to IGW)
    + Private (route to NAT Gateway)
    + Protected (no route to INet)
  * Route tables for each subnet

To answer the question of why only two AZs instead of three or four, it's frankly because not all regions support more than two AZs. Besides, you're getting diminishing returns the more you spread that out, there aren't a lot of times (any?) when two Availability Zones in a region have been wiped out, and if it happens it's more likely that an entire region is down, in which case you better have a DR plan in place anyway.

### bastion.yaml

Deploys "bastion" host resources. Features include:

  * Bastion host is an Autoscaling group of 1 instance, spanning two subnets (presumably across different AZs for automatic replacement if one AZ fails, but it's your choice if you want to be stupid)
  * Configuration accepts an AMI ID, or will pick the latest Amazon Linux 2 image for the associated region
  * Accepts a list of security-groups to use, or alternatively supply a CIDR range to whitelist to create a new security-group

### sg.yaml

Creates a security group that allows full outbound access, but inbout access from a given IP range on a given port (both of those factors are determined by parameters). This is a very simple security group, with the assumption that multiple rules should be separated into different SGs and stacked (default is up to five SGs per ENI). If more complex rules are required in a single SG, this will have to be done separately.

TO-DO: plan to make this simple security-group resource capable of either IP range definition or security-group based rules (e.g. allowing ingress traffic from a given security group ID).

### flowlogs.yaml

Creates an IAM Role that grants the necessary permissions to create and read log events in CloudWatch Logs, then uses that to create a VPC FlowLog log group for the VPC indicated in the template parameter.

## Helpers

### s3sync.sh

Copies the current directory files to an opinionated location in an S3 bucket, so that parent stack templates can reference child-stack S3 URIs.
