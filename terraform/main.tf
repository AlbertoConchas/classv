provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "test-classv"
    key    = "terraform/"
    region = "us-east-1"
  }
}

module "network" {
  source = "./modules/network"
}

module "eks" {
  source = "./modules/eks"

  cluster-name           = "eks-classv"
  private-subnet-1-cidr  = "172.16.3.0/24"
  private-subnet-2-cidr  = "172.16.4.0/24"
  private-route-table-id = "${module.network.route-table-id}"
  aws_vpc                = "${module.network.vpc-id}"
  office-ip                 = "189.209.62.211/32"
  max_size               = 2
  desired_capacity       = 2
  enable_alb_sg          = false
  instance-type          = "t3.large"
  alb_sg_cidr            = ""
}
module "assumed-roles" {
  source = "./modules/assumed-roles"
  role_arn    = "${module.eks.role_arn}"
}

module "ecr" {
  source = "./modules/ecr"
}
