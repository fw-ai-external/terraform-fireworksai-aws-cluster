locals {
  create_vpc = var.vpc.existing_vpc_id == null
  # Only create subnets that do not have an existing subnet ID
  availability_zones = {
    for az_name, az_config in var.availability_zones : az_name => {
      public_cidr  = az_config.public_cidr
      private_cidr = az_config.private_cidr
    } if az_config.existing_subnet_id == null
  }
}

resource "aws_vpc" "fireworks_vpc" {
  count      = local.create_vpc ? 1 : 0
  cidr_block = var.vpc.cidr
  tags = {
    Name                   = "vpc-fireworks-${data.aws_region.current.name}"
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_default_network_acl" "acl" {
  count                  = local.create_vpc ? 1 : 0
  default_network_acl_id = aws_vpc.fireworks_vpc[0].default_network_acl_id
  subnet_ids             = concat(values(aws_subnet.public)[*].id, values(aws_subnet.private)[*].id)
  egress {
    rule_no    = 100
    cidr_block = "0.0.0.0/0"
    protocol   = -1
    action     = "allow"
    from_port  = 0
    to_port    = 0
  }
  ingress {
    rule_no    = 100
    cidr_block = "0.0.0.0/0"
    protocol   = -1
    action     = "allow"
    from_port  = 0
    to_port    = 0
  }
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = local.create_vpc ? 1 : 0
  name  = "/fireworks/vpc-flow-logs/${aws_vpc.fireworks_vpc[0].id}"
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_flow_log" "vpc_flow_log" {
  count           = local.create_vpc ? 1 : 0
  vpc_id          = aws_vpc.fireworks_vpc[0].id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.vpc_flow_logger[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_subnet" "public" {
  for_each = local.availability_zones

  vpc_id                  = coalesce(var.vpc.existing_vpc_id, try(aws_vpc.fireworks_vpc[0].id, null))
  availability_zone       = each.key
  cidr_block              = each.value.public_cidr
  map_public_ip_on_launch = true
  tags = {
    "Name"                 = "fireworks-public-${each.key}"
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_subnet" "private" {
  for_each = local.availability_zones

  vpc_id            = coalesce(var.vpc.existing_vpc_id, try(aws_vpc.fireworks_vpc[0].id, null))
  availability_zone = each.key
  cidr_block        = each.value.private_cidr
  tags = {
    "Name"                            = "fireworks-private-${each.key}",
    "kubernetes.io/role/internal-elb" = "1"
    "fireworks.ai:managed"            = "true"
  }
}

resource "aws_eip" "nat_ip" {
  for_each = local.availability_zones
  tags = {
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_nat_gateway" "nat" {
  for_each      = local.availability_zones
  subnet_id     = aws_subnet.public[each.key].id
  allocation_id = aws_eip.nat_ip[each.key].id
  tags = {
    "Name"                 = "fireworks-nat-${each.key}"
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_internet_gateway" "igw" {
  count  = local.create_vpc ? 1 : 0
  vpc_id = aws_vpc.fireworks_vpc[0].id
  tags = {
    "Name"                 = "fireworks-igw"
    "fireworks.ai:managed" = "true"
  }
}

data "aws_internet_gateway" "existing_igw" {
  count = local.create_vpc ? 0 : 1
  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc.existing_vpc_id]
  }
}

resource "aws_route_table" "public" {
  for_each = local.availability_zones
  vpc_id   = coalesce(var.vpc.existing_vpc_id, try(aws_vpc.fireworks_vpc[0].id, null))
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = local.create_vpc ? aws_internet_gateway.igw[0].id : data.aws_internet_gateway.existing_igw[0].id
  }
  tags = {
    "Name"                 = "fireworks-route-table-public-${each.key}"
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_route_table" "private" {
  for_each = local.availability_zones
  vpc_id   = coalesce(var.vpc.existing_vpc_id, try(aws_vpc.fireworks_vpc[0].id, null))
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }
  tags = {
    "Name"                 = "fireworks-route-table-private-${each.key}"
    "fireworks.ai:managed" = "true"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = local.availability_zones
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each       = local.availability_zones
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
