variable "vpc" {
  type = object({
    existing_vpc_id = optional(string)
    cidr            = optional(string)
  })
  description = "VPC configuration for Fireworks clusters. If `existing_vpc_id` is supplied, all other fields in the map are ignored and no VPC will be created."
}

variable "availability_zones" {
  type = map(object({
    existing_subnet_id                      = optional(string) # Must be set if public_cidr and private_cidr are not set
    public_cidr                             = optional(string) # Must be set if existing_subnet_id is not set
    private_cidr                            = optional(string) # Must be set if existing_subnet_id is not set
    node_count                              = number
    instance_type                           = string
    capacity_reservation_resource_group_arn = optional(string)
  }))
  description = "A mapping from availability zones to the configuration of a node group that will be created in that AZ"
}

variable "enable_metrics_to_fireworks" {
  type        = bool
  description = "Whether or not to send aggregated inference metrics back to Fireworks"
  default     = true
}

variable "existing_s3_bucket_arn" {
  type        = string
  description = "The ARN of an existing S3 bucket for writing Fireworks data. Ensure the cluster node IAM role can write to this bucket."
  default     = ""
}

variable "s3_bucket_suffix" {
  type        = string
  description = "A suffix for the name of the created S3 bucket. A random string will be used if this is left blank."
  default     = ""

  validation {
    condition     = length(var.s3_bucket_suffix) <= 16
    error_message = "s3_bucket_suffix cannot be longer than 16 characters"
  }
}

variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster to be created."
}

variable "existing_iam_roles" {
  type = object({
    fireworks_manager_role_arn      = string
    cluster_node_role_arn           = string
    eks_cluster_role_arn            = string
    eks_cluster_autoscaler_role_arn = string
  })
  description = "ARNs of existing Fireworks system roles (e.g. from a different instance of this module). If supplied, these roles will not be recreated."
  default     = null
}

variable "use_secondary_manager_role_name" {
  type        = bool
  description = "If true, the Fireworks manager IAM role will be named FireworksClusterManagerRole instead of FireworksManagerRole. This is useful if you already have a FireworksManagerRole from Firework's DLDE."
  default     = false
}

variable "existing_ecr_repo_uris" {
  type = object({
    text_completion_ecr_repo_uri = string
    llm_downloader_ecr_repo_uri  = string
  })
  description = "URIs of existing Fireworks ECR repos. If supplied, these repositories will not be recreated."
  default     = null
}
