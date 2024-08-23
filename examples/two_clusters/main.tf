module "fireworks_cluster_1" {
  source  = "fw-ai-external/aws-cluster/fireworksai"
  version = "0.1.0"

  vpc = {
    cidr = "172.19.0.0/16"
  }
  availability_zones = {
    "us-east-1a" = {
      public_cidr   = "172.19.0.0/20"  # must be within the VPC range
      private_cidr  = "172.19.16.0/20" # must be within the VPC range
      node_count    = "1"
      instance_type = "p5.48xlarge" # p4d.24xlarge and p4de.24xlarge are also supported
    }
    "us-east-1b" = {
      public_cidr   = "172.19.32.0/20" # must be within the VPC range
      private_cidr  = "172.19.48.0/20" # must be within the VPC range
      node_count    = "1"
      instance_type = "p5.48xlarge" # p4d.24xlarge and p4de.24xlarge are also supported
    }
  }
  cluster_name = "my-cluster-1"
}

output "fireworks_cluster_1" {
  value = module.fireworks_cluster_1
}

# You may need to apply `fireworks_cluster_1` before you can apply `fireworks_cluster_2`.
module "fireworks_cluster_2" {
  source  = "fw-ai-external/aws-cluster/fireworksai"
  version = "0.1.0"

  vpc = {
    existing_vpc_id = module.fireworks_cluster_1.vpc_id
  }
  availability_zones = {
    "us-east-1a" = {
      existing_subnet_id = module.fireworks_cluster_1.availability_zone_subnets["us-east-1a"].subnet_id
      node_count         = "1"
      instance_type      = "p5.48xlarge" # p4d.24xlarge and p4de.24xlarge are also supported
    }
    "us-east-1b" = {
      existing_subnet_id = module.fireworks_cluster_1.availability_zone_subnets["us-east-1b"].subnet_id
      node_count         = "1"
      instance_type      = "p5.48xlarge" # p4d.24xlarge and p4de.24xlarge are also supported
    }
  }
  existing_iam_roles = {
    fireworks_manager_role_arn      = module.fireworks_cluster_1.fireworks_manager_role_arn
    cluster_node_role_arn           = module.fireworks_cluster_1.cluster_node_role_arn
    eks_cluster_role_arn            = module.fireworks_cluster_1.eks_cluster_role_arn
    eks_cluster_autoscaler_role_arn = module.fireworks_cluster_1.eks_cluster_autoscaler_role_arn
  }
  existing_ecr_repo_uris = {
    llm_downloader_ecr_repo_uri  = module.fireworks_cluster_1.llm_downloader_ecr_repo_uri
    text_completion_ecr_repo_uri = module.fireworks_cluster_1.text_completion_ecr_repo_uri
  }
  existing_s3_bucket_arn = module.fireworks_cluster_1.s3_bucket_arn
  cluster_name           = "my-cluster-2"
}

output "fireworks_cluster_existing_everything" {
  value = module.fireworks_cluster_2
}