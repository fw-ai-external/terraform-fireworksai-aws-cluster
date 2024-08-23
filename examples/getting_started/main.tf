module "fireworks_cluster" {
  source  = "fw-ai-external/aws-cluster/fireworksai"
  version = "0.1.0"

  vpc = {
    cidr = "172.19.0.0/16"
  }
  availability_zones = {
    "us-east-1a" = {
      public_cidr   = "172.19.0.0/20"  # must be within the VPC range
      private_cidr  = "172.19.16.0/20" # must be within the VPC range
      node_count    = "0"
      instance_type = "p5.48xlarge" # p4d.24xlarge and p4de.24xlarge are also supported
    }
    "us-east-1b" = {
      public_cidr   = "172.19.32.0/20" # must be within the VPC range
      private_cidr  = "172.19.48.0/20" # must be within the VPC range
      node_count    = "0"
      instance_type = "p5.48xlarge" # p4d.24xlarge and p4de.24xlarge are also supported
    }
  }
  cluster_name = "my-cluster"
}

output "fireworks_cluster" {
  value = module.fireworks_cluster
}