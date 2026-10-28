# Public subnets only, no NAT gateway. Fargate tasks get a public IP so they
# can pull from ECR and reach Open-Meteo; the task security group still only
# accepts traffic from the ALB, so the public IP is not an open door.
# A NAT gateway would cost more than the rest of this lab combined.

module "network" {
  source = "./modules/network"

  name                = var.project
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  availability_zones  = var.availability_zones
}
