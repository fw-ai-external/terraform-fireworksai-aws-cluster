terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
}

module "fireworks_cluster" {
  source  = "fw-ai-external/aws-cluster/fireworksai"
  version = "0.1.3"

  vpc = {
    cidr = "172.19.0.0/16"
  }
  availability_zones = {
    "us-east-2a" = {
      public_cidr             = "172.19.0.0/20"
      private_cidr            = "172.19.16.0/20"
      node_count              = "1"
      instance_type           = "p5.48xlarge" # H100
      capacity_reservation_id = "cr-1234567890"
      capacity_type           = "CAPACITY_BLOCK"
      instance_market_type    = "capacity-block"
    }
    "us-east-2b" = {
      public_cidr   = "172.19.32.0/20"
      private_cidr  = "172.19.48.0/20"
      node_count    = "0"
      instance_type = "p5.48xlarge" # H100
    }
  }
  cluster_name = "my-cluster"
  ec2_tags = {
    "my-tag" = "my-value"
  }
}

output "fireworks_cluster" {
  value = module.fireworks_cluster
}