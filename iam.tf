locals {
  create_core_roles = var.existing_iam_roles == null
}

resource "aws_iam_role" "fireworks_manager_role" {
  count              = local.create_core_roles ? 1 : 0
  name               = var.use_secondary_manager_role_name ? "FireworksClusterManagerRole" : "FireworksManagerRole"
  description        = "Role assumed by the Fireworks control plane to manage resources."
  assume_role_policy = data.aws_iam_policy_document.fireworks_manager_trust_policy.json
  inline_policy {
    name   = "FireworksClusterManagerPolicy"
    policy = data.aws_iam_policy_document.fireworks_manager_policy.json
  }
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  count              = local.create_core_roles ? 1 : 0
  name               = "FireworksEKSClusterRole"
  description        = "Amazon EKS Cluster role for Fireworks clusters."
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_role_trust_policy.json
  # https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"]
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_iam_role" "cluster_node_role" {
  count              = local.create_core_roles ? 1 : 0
  name               = "FireworksClusterNodeRole"
  description        = "Role used by Fireworks cluster nodes."
  assume_role_policy = data.aws_iam_policy_document.cluster_node_role_trust_policy.json
  # https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
  ]
  inline_policy {
    name   = "FireworksClusterNodePolicy"
    policy = data.aws_iam_policy_document.cluster_node_policy.json
  }
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_iam_role" "eks_cluster_autoscaler_role" {
  count               = local.create_core_roles ? 1 : 0
  name                = "FireworksEKSClusterAutoscalerRole"
  description         = "Amazon EKS Cluster autoscaler role for Fireworks clusters."
  assume_role_policy  = data.aws_iam_policy_document.dummy_trust_policy.json
  managed_policy_arns = [aws_iam_policy.eks_cluster_autoscaler_policy[0].arn]

  lifecycle {
    ignore_changes = [
      # Ignore changes to the trust policy since OIDC providers are dynamically
      # added to this role's trust policy during cluster creation.
      assume_role_policy,
      description,
    ]
  }
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

# This role must be created for each cluster because the trust policy relies on the OIDC issuer of the cluster.
resource "aws_iam_role" "eks_load_balancer_controller_role" {
  name                = substr("FireworksEKSLoadBalancerControllerRole-${var.cluster_name}", 0, 64)
  description         = "Role used by the AWS Load Balancer Controller for Fireworks clusters."
  assume_role_policy  = data.aws_iam_policy_document.eks_load_balancer_controller_role_trust_policy.json
  managed_policy_arns = [aws_iam_policy.eks_load_balancer_controller_iam_policy.arn]
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

# This role must be created for each cluster because the trust policy relies on the OIDC issuer of the cluster.
resource "aws_iam_role" "metrics_writer_role" {
  count              = var.enable_metrics_to_fireworks ? 1 : 0
  name               = substr("FireworksMetricWriterRole-${var.cluster_name}", 0, 64)
  description        = "Role used to write to metrics back to Fireworks."
  assume_role_policy = data.aws_iam_policy_document.metrics_writer_role_trust_policy[0].json
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

# This role must be created for each cluster because the trust policy relies on the OIDC issuer of the cluster.
resource "aws_iam_role" "inference_role" {
  name               = substr("FireworksInferenceRole-${var.cluster_name}", 0, 64)
  description        = "Role used to by inference pods in the cluster."
  assume_role_policy = data.aws_iam_policy_document.inference_role_trust_policy.json
  inline_policy {
    name   = "FireworksInferencePolicy"
    policy = data.aws_iam_policy_document.inference_policy.json
  }
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_iam_role" "vpc_flow_logger" {
  count               = local.create_vpc ? 1 : 0
  name                = "FireworksVpcFlowLogger"
  description         = "Role used to write to Fireworks VPC flow logs."
  assume_role_policy  = data.aws_iam_policy_document.vpc_flow_logger_trust_policy.json
  managed_policy_arns = [aws_iam_policy.vpc_flow_logger_policy[0].arn]
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

data "aws_iam_policy_document" "fireworks_manager_trust_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["accounts.google.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "accounts.google.com:aud"
      values   = ["117388763667264115668"] // Fireworks Control Plane
    }
  }
}

data "aws_iam_policy_document" "eks_cluster_role_trust_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cluster_node_role_trust_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eks_load_balancer_controller_role_trust_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${local.aws_account_id}:oidc-provider/${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

data "aws_iam_policy_document" "metrics_writer_role_trust_policy" {
  count = var.enable_metrics_to_fireworks ? 1 : 0
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${local.aws_account_id}:oidc-provider/${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:gmp-system:collector"]
    }
  }
}

data "aws_iam_policy_document" "inference_role_trust_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${local.aws_account_id}:oidc-provider/${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:default:inference"]
    }
  }
}

data "aws_iam_policy_document" "fireworks_manager_policy" {
  statement {
    actions   = ["eks:*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/fireworks.ai:managed"
      values   = ["true"]
    }
  }
  statement {
    actions   = ["ecr:*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/fireworks.ai:managed"
      values   = ["true"]
    }
  }
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "cluster_node_policy" {
  statement {
    actions   = ["ecr:*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/fireworks.ai:managed"
      values   = ["true"]
    }
  }
}

data "aws_iam_policy_document" "inference_policy" {
  statement {
    actions = [
      "s3:Get*",
      "s3:List*",
      "s3:Describe*",
    ]
    resources = ["${coalesce(var.existing_s3_bucket_arn, try(aws_s3_bucket.fireworks_bucket[0].arn, null))}/*"]
  }
  statement {
    actions = [
      "s3:List*",
    ]
    resources = [coalesce(var.existing_s3_bucket_arn, try(aws_s3_bucket.fireworks_bucket[0].arn, null))]
  }
}

resource "aws_iam_policy" "eks_load_balancer_controller_iam_policy" {
  name = substr("FireworksEKSLoadBalancerControllerIAMPolicy-${var.cluster_name}", 0, 64)
  # https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
  # Copied from https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "iam:CreateServiceLinkedRole"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "iam:AWSServiceName" : "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateSecurityGroup"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateTags"
        ],
        "Resource" : "arn:aws:ec2:*:*:security-group/*",
        "Condition" : {
          "StringEquals" : {
            "ec2:CreateAction" : "CreateSecurityGroup"
          },
          "Null" : {
            "aws:RequestTag/elbv2.k8s.aws/cluster" : "false"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ],
        "Resource" : "arn:aws:ec2:*:*:security-group/*",
        "Condition" : {
          "Null" : {
            "aws:RequestTag/elbv2.k8s.aws/cluster" : "true",
            "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup"
        ],
        "Resource" : "*",
        "Condition" : {
          "Null" : {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ],
        "Resource" : "*",
        "Condition" : {
          "Null" : {
            "aws:RequestTag/elbv2.k8s.aws/cluster" : "false"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ],
        "Resource" : [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ],
        "Condition" : {
          "Null" : {
            "aws:RequestTag/elbv2.k8s.aws/cluster" : "true",
            "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ],
        "Resource" : [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup"
        ],
        "Resource" : "*",
        "Condition" : {
          "Null" : {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" : "false"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:AddTags"
        ],
        "Resource" : [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ],
        "Condition" : {
          "StringEquals" : {
            "elasticloadbalancing:CreateAction" : [
              "CreateTargetGroup",
              "CreateLoadBalancer"
            ]
          },
          "Null" : {
            "aws:RequestTag/elbv2.k8s.aws/cluster" : "false"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ],
        "Resource" : "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule"
        ],
        "Resource" : "*"
      }
    ]
  })
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

data "aws_iam_policy_document" "dummy_trust_policy" {
  # OIDC providers are dynamically added to this role's trust policy during
  # cluster creation. This entry is just a placeholder because Statements cannot
  # be empty.
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "eks_cluster_autoscaler_policy" {
  count       = local.create_core_roles ? 1 : 0
  name        = "FireworksEKSClusterAutoscalerPolicy"
  description = "Policy used by the FireworksEKSClusterAutoscalerRole to manage resources in the account."
  policy      = data.aws_iam_policy_document.eks_cluster_autoscaler_policy_document.json

  lifecycle {
    ignore_changes = [description]
  }
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

data "aws_iam_policy_document" "eks_cluster_autoscaler_policy_document" {
  version = "2012-10-17"

  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeImages",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "vpc_flow_logger_trust_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "vpc_flow_logger_policy" {
  count = local.create_core_roles ? 1 : 0
  name  = "FireworksVpcFlowLoggerPolicy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:ResourceTag/fireworks.ai:managed" : "true"
          }
        }
      },
    ],
  })
  tags = {
    "fireworks.ai:managed" = "true"
  }
}
