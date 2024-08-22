locals {
  bucket_suffix = try(coalesce(var.s3_bucket_suffix, random_id.default_bucket_suffix[0].hex), "")
}

resource "random_id" "default_bucket_suffix" {
  count       = var.existing_s3_bucket_arn == "" ? 1 : 0
  byte_length = 4
}

resource "aws_s3_bucket" "fireworks_bucket" {
  count = var.existing_s3_bucket_arn == "" ? 1 : 0
  # Max 63 characters. We want to ensure the entire suffix is shown so that different accounts
  # can have the same cluster name. To do this we need to truncate the cluster name accordingly.
  bucket = "fireworks-${
    substr(var.cluster_name, 0, 63 - length("fireworks-") - length("-${local.bucket_suffix}"))
  }-${local.bucket_suffix}"
  tags = {
    "fireworks.ai:managed" = "true"
  }
}
