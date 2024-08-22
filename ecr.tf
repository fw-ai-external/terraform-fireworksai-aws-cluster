locals {
  create_ecr_repos = var.existing_ecr_repo_uris == null
}

resource "aws_ecr_repository" "llm_downloader" {
  count = local.create_ecr_repos ? 1 : 0
  name  = "fireworks/llm-downloader"
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_ecr_repository" "text_completion" {
  count = local.create_ecr_repos ? 1 : 0
  name  = "fireworks/text-completion"
  tags = {
    "fireworks.ai:managed" = "true"
  }
}
