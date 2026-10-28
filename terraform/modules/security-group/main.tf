# A security group whose rules can name either a CIDR or another security
# group as the peer. Rules use count rather than for_each: a referenced group's
# ID is unknown until apply, and for_each keys must be known at plan time.

resource "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  tags = { Name = var.name }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  count = length(var.ingress_rules)

  security_group_id            = aws_security_group.this.id
  description                  = var.ingress_rules[count.index].description
  ip_protocol                  = var.ingress_rules[count.index].ip_protocol
  from_port                    = var.ingress_rules[count.index].from_port
  to_port                      = var.ingress_rules[count.index].to_port
  cidr_ipv4                    = var.ingress_rules[count.index].cidr_ipv4
  referenced_security_group_id = var.ingress_rules[count.index].referenced_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "this" {
  count = length(var.egress_rules)

  security_group_id            = aws_security_group.this.id
  description                  = var.egress_rules[count.index].description
  ip_protocol                  = var.egress_rules[count.index].ip_protocol
  from_port                    = var.egress_rules[count.index].from_port
  to_port                      = var.egress_rules[count.index].to_port
  cidr_ipv4                    = var.egress_rules[count.index].cidr_ipv4
  referenced_security_group_id = var.egress_rules[count.index].referenced_security_group_id
}
