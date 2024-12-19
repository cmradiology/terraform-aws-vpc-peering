resource "aws_vpc_peering_connection" "default" {
  provider    = aws.requestor
  count       = module.this.enabled ? 1 : 0
  vpc_id      = join("", data.aws_vpc.requestor[*].id)
  peer_vpc_id = join("", data.aws_vpc.acceptor[*].id)
  peer_region = data.aws_region.acceptor[0].name

  tags = module.this.tags

  timeouts {
    create = var.create_timeout
    update = var.update_timeout
    delete = var.delete_timeout
  }
}

resource "aws_vpc_peering_connection_accepter" "acceptor" {
  provider                  = aws.acceptor
  count                     = module.this.enabled ? 1 : 0
  vpc_peering_connection_id = aws_vpc_peering_connection.default[0].id
  auto_accept               = var.auto_accept
}

resource "aws_vpc_peering_connection_options" "requestor" {
  provider = aws.requestor

  # As options can't be set until the connection has been accepted
  # create an explicit dependency on the acceptor.
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.acceptor[0].id

  requester {
    allow_remote_vpc_dns_resolution = var.requestor_allow_remote_vpc_dns_resolution
  }
}

resource "aws_vpc_peering_connection_options" "acceptor" {
  provider = aws.acceptor

  # As options can't be set until the connection has been accepted
  # create an explicit dependency on the acceptor.
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.acceptor[0].id

  accepter {
    allow_remote_vpc_dns_resolution = var.acceptor_allow_remote_vpc_dns_resolution
  }
}

data "aws_region" "acceptor" {
  provider = aws.acceptor
  count    = module.this.enabled ? 1 : 0
}

# Lookup requestor VPC so that we can reference the CIDR
data "aws_vpc" "requestor" {
  provider = aws.requestor
  count    = module.this.enabled ? 1 : 0
  id       = var.requestor_vpc_id
  tags     = var.requestor_vpc_tags
}

# Lookup acceptor VPC so that we can reference the CIDR
data "aws_vpc" "acceptor" {
  provider = aws.acceptor
  count    = module.this.enabled ? 1 : 0
  id       = var.acceptor_vpc_id
  tags     = var.acceptor_vpc_tags
}

data "aws_route_tables" "requestor" {
  provider = aws.requestor
  count    = module.this.enabled ? 1 : 0
  vpc_id   = join("", data.aws_vpc.requestor[*].id)
  tags     = var.requestor_route_table_tags
}

data "aws_route_tables" "acceptor" {
  provider = aws.acceptor
  count    = module.this.enabled ? 1 : 0
  vpc_id   = join("", data.aws_vpc.acceptor[*].id)
  tags     = var.acceptor_route_table_tags
}

locals {
  requestor_cidr_blocks = module.this.enabled ? tolist(setsubtract([
    for k, v in data.aws_vpc.requestor[0].cidr_block_associations : v.cidr_block
  ], var.requestor_ignore_cidrs)) : []
  acceptor_cidr_blocks = module.this.enabled ? tolist(setsubtract([
    for k, v in data.aws_vpc.acceptor[0].cidr_block_associations : v.cidr_block
  ], var.acceptor_ignore_cidrs)) : []
}

# Create routes from requestor to acceptor
resource "aws_route" "requestor" {
  provider                  = aws.requestor
  count                     = module.this.enabled ? length(distinct(sort(data.aws_route_tables.requestor[0].ids))) * length(local.acceptor_cidr_blocks) : 0
  route_table_id            = element(distinct(sort(data.aws_route_tables.requestor[0].ids)), ceil(count.index / length(local.acceptor_cidr_blocks)))
  destination_cidr_block    = local.acceptor_cidr_blocks[count.index % length(local.acceptor_cidr_blocks)]
  vpc_peering_connection_id = join("", aws_vpc_peering_connection.default[*].id)
  depends_on                = [data.aws_route_tables.requestor, aws_vpc_peering_connection.default]
}

# Create routes from acceptor to requestor
resource "aws_route" "acceptor" {
  provider                  = aws.acceptor
  count                     = module.this.enabled ? length(distinct(sort(data.aws_route_tables.acceptor[0].ids))) * length(local.requestor_cidr_blocks) : 0
  route_table_id            = element(distinct(sort(data.aws_route_tables.acceptor[0].ids)), ceil(count.index / length(local.requestor_cidr_blocks)))
  destination_cidr_block    = local.requestor_cidr_blocks[count.index % length(local.requestor_cidr_blocks)]
  vpc_peering_connection_id = join("", aws_vpc_peering_connection.default[*].id)
  depends_on                = [data.aws_route_tables.acceptor, aws_vpc_peering_connection.default]
}
