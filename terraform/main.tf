variable "stack_name" {
  default = "tools"
  description = "This is the name that is prefixed to the resources."
}

variable "vpc_cidr_range" {
  default = "10.128.16.0/20"
  description = "The CIDR range for the VPC."
}

variable "subnet_cidr_range" {
  default = "10.128.16.0/24"
  description = "The CIDR range for the subnet."
}

variable "availability_zone" {
  default = "eu-west-1a"
  description = "The availability zone into which to create the subnet."
}

variable "coreos_owner" {
  default = "595879546273"
  description = "The account ID for the owner of the CoreOS AMI."
}

variable "aws_region" {
  default = "eu-west-1"
  description = "The region to use for deploying the stack."
}

provider "aws" {
  region = "${var.aws_region}"
}

data "aws_ami" "coreos" {
  most_recent = true
  filter {
    name = "name"
    values = ["CoreOS-stable-*"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["${var.coreos_owner}"]
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  filter {
    name = "name"
    values = ["amzn-ami-hvm-*"]
  }
  filter {
    name = "owner-alias"
    values = ["amazon"]
  }
  filter {
    name = "block-device-mapping.volume-type"
    values = ["gp2"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "vpc" {
  cidr_block = "${var.vpc_cidr_range}"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags {
    Name = "${var.stack_name}-vpc"
  }
}

resource "aws_default_route_table" "default_rtb" {
  default_route_table_id = "${aws_vpc.vpc.default_route_table_id}"
  tags {
    Name = "${var.stack_name}-default-rtb"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags {
    Name = "${var.stack_name}-igw"
  }
}

resource "aws_route_table" "public_rtb" {
  vpc_id = "${aws_vpc.vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
  tags {
    Name = "${var.stack_name}-public-rtb"
  }
}

resource "aws_subnet" "subnet" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.subnet_cidr_range}"
  availability_zone = "${var.availability_zone}"
  map_public_ip_on_launch = true
  tags {
    Name = "${var.stack_name}-subnet"
  }
}

resource "aws_route_table_association" "subnet_rtb" {
  subnet_id = "${aws_subnet.subnet.id}"
  route_table_id = "${aws_route_table.public_rtb.id}"
}

resource "aws_route53_zone" "zone" {
  name = "superwatermelon.org"
  comment = "The internal private hosted zone"
  vpc_id = "${aws_vpc.vpc.id}"
  tags {
    Name = "${var.stack_name}-zone"
  }
}

resource "aws_route53_record" "git_record" {
  zone_id = "${aws_route53_zone.zone.zone_id}"
  name = "git.superwatermelon.org"
  type = "A"
  ttl = "300"
  records = ["${var.git_private_ip}"]
}