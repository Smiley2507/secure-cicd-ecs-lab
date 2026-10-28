# One host for Jenkins and SonarQube. The scanners themselves run as
# short-lived containers on it during each build.

module "key_pair" {
  source = "./modules/key-pair"

  key_name         = "${var.project}-key"
  private_key_path = var.private_key_path
}

module "jenkins" {
  source = "./modules/ec2-instance"

  name                 = "${var.project}-jenkins"
  ami_id               = var.ami_id
  instance_type        = var.jenkins_instance_type
  subnet_id            = module.network.public_subnet_ids[0]
  security_group_ids   = [module.jenkins_sg.security_group_id]
  key_name             = module.key_pair.key_name
  iam_instance_profile = module.jenkins_role.instance_profile_name
  root_volume_size     = var.jenkins_root_volume_size

  # The Ansible inventory groups hosts by this tag: Role=jenkins -> role_jenkins
  tags = { Role = "jenkins" }
}
