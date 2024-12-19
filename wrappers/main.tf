module "wrapper" {
  source = "./.."

  providers = {
    aws.requestor = aws.requestor
    aws.acceptor  = aws.acceptor
  }

  requestor_vpc_id                          = var.requestor_vpc_id
  requestor_vpc_tags                        = var.requestor_vpc_tags
  requestor_route_table_tags                = var.requestor_route_table_tags
  acceptor_vpc_id                           = var.acceptor_vpc_id
  acceptor_vpc_tags                         = var.acceptor_vpc_tags
  acceptor_route_table_tags                 = var.acceptor_route_table_tags
  auto_accept                               = var.auto_accept
  acceptor_allow_remote_vpc_dns_resolution  = var.acceptor_allow_remote_vpc_dns_resolution
  requestor_allow_remote_vpc_dns_resolution = var.requestor_allow_remote_vpc_dns_resolution
  create_timeout                            = var.create_timeout
  update_timeout                            = var.update_timeout
  delete_timeout                            = var.delete_timeout
  requestor_ignore_cidrs                    = var.requestor_ignore_cidrs
  acceptor_ignore_cidrs                     = var.acceptor_ignore_cidrs
}
