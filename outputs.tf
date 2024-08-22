output "s3_bucket_arn" {
  description = "ARN of the S3 bucket to be used to store Fireworks data."
  value       = coalesce(var.existing_s3_bucket_arn, try(aws_s3_bucket.fireworks_bucket[0].arn, null))
}

output "fireworks_manager_role_arn" {
  description = "ARN of the IAM role assumed by the Fireworks control plane to manage resources."
  value       = try(var.existing_iam_roles.fireworks_manager_role_arn, aws_iam_role.fireworks_manager_role[0].arn)
}

output "cluster_node_role_arn" {
  description = "ARN of the IAM role used by cluster nodes."
  value       = try(var.existing_iam_roles.cluster_node_role_arn, aws_iam_role.cluster_node_role[0].arn)
}

output "eks_cluster_role_arn" {
  description = "ARN of the IAM role used by the EKS cluster."
  value       = try(var.existing_iam_roles.eks_cluster_role_arn, aws_iam_role.eks_cluster_role[0].arn)
}

output "eks_cluster_autoscaler_role_arn" {
  description = "ARN of the IAM role used by EKS cluster autoscaler."
  value       = try(var.existing_iam_roles.eks_cluster_autoscaler_role_arn, aws_iam_role.eks_cluster_autoscaler_role[0].arn)
}

output "eks_load_balancer_controller_role_arn" {
  description = "ARN of the IAM role used by the AWS Load Balancer Controller for Fireworks clusters."
  value       = aws_iam_role.eks_load_balancer_controller_role.arn
}

output "metrics_writer_role_arn" {
  description = "ARN of the IAM role used to write to metrics back to Fireworks."
  value       = try(aws_iam_role.metrics_writer_role[0].arn, "")
}

output "inference_role_arn" {
  description = "ARN of the IAM role used by inference pods in the cluster."
  value       = aws_iam_role.inference_role.arn
}

output "text_completion_ecr_repo_uri" {
  description = "URI of the ECR repo for inference images"
  value       = try(var.existing_ecr_repo_uris.text_completion_ecr_repo_uri, aws_ecr_repository.text_completion[0].repository_url)
}

output "llm_downloader_ecr_repo_uri" {
  description = "URI of the ECR repo for model downloading images"
  value       = try(var.existing_ecr_repo_uris.llm_downloader_ecr_repo_uri, aws_ecr_repository.llm_downloader[0].repository_url)
}

output "vpc_id" {
  description = "The ID of the VPC used for the cluster."
  value       = coalesce(var.vpc.existing_vpc_id, try(aws_vpc.fireworks_vpc[0].id, null))
}

output "availability_zone_subnets" {
  description = "The subnet used by the cluster node group in each availability zone."
  value       = local.availability_zone_subnets
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = var.cluster_name
}
