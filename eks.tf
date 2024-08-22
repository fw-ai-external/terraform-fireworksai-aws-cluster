locals {
  availability_zone_subnets = {
    for az_name, az_config in var.availability_zones : az_name => {
      subnet_id = coalesce(az_config.existing_subnet_id, try(aws_subnet.private[az_name].id, null))
    }
  }
  eks_cluster_role_arn  = try(var.existing_iam_roles.eks_cluster_role_arn, aws_iam_role.eks_cluster_role[0].arn)
  cluster_node_role_arn = try(var.existing_iam_roles.cluster_node_role_arn, aws_iam_role.cluster_node_role[0].arn)
}

resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  role_arn = local.eks_cluster_role_arn
  vpc_config {
    subnet_ids = [for _, v in local.availability_zone_subnets : v.subnet_id]
  }
  version                   = "1.29"
  enabled_cluster_log_types = ["api"]
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc_certificate.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

data "tls_certificate" "oidc_certificate" {
  url = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_launch_template" "system" {
  instance_type = "t3.medium"
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  update_default_version = true
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_launch_template" "launch_template" {
  for_each = {
    for az, config in var.availability_zones :
    az => config if config.node_count != 0
  }

  instance_type = each.value.instance_type
  placement {
    availability_zone = each.key
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 1000 # GB
      volume_type = "gp3"
    }
  }
  capacity_reservation_specification {
    capacity_reservation_target {
      capacity_reservation_resource_group_arn = each.value.capacity_reservation_resource_group_arn
    }
  }
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  update_default_version = true
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "system"
  node_role_arn   = local.cluster_node_role_arn
  subnet_ids      = [for _, v in local.availability_zone_subnets : v.subnet_id]
  launch_template {
    id      = aws_launch_template.system.id
    version = aws_launch_template.system.latest_version
  }
  scaling_config {
    desired_size = 3
    min_size     = 3
    max_size     = 3
  }
  labels = {
    "fireworks.ai/system" = "true"
  }
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_eks_node_group" "node_group" {
  for_each = {
    for az, config in var.availability_zones :
    az => config if config.node_count != 0
  }

  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = format("%s-%s", replace(each.value.instance_type, ".", "-"), each.key)
  ami_type        = "AL2_x86_64_GPU"
  launch_template {
    id      = aws_launch_template.launch_template[each.key].id
    version = aws_launch_template.launch_template[each.key].latest_version
  }
  node_role_arn = local.cluster_node_role_arn
  scaling_config {
    desired_size = each.value.node_count
    min_size     = each.value.node_count
    max_size     = each.value.node_count
  }
  subnet_ids = [local.availability_zone_subnets[each.key].subnet_id]
  taint {
    key    = "nvidia.com/gpu"
    value  = "present"
    effect = "NO_SCHEDULE"
  }
  labels = {
    # For the EKS NVMe provisioner: https://github.com/brunsgaard/eks-nvme-ssd-provisioner
    "aws.amazon.com/eks-local-ssd" = "true"
    # On EKS there are no default labels that indicate a node has a GPU, so we can add one
    # ourselves. An example usage is a DCGM exporter daemonset using this to target GPU nodes.
    "fireworks.ai/eks-gpu" = "true"
  }
  tags = {
    "fireworks.ai:managed" = "true"
  }
}
