terraform {
  backend "s3" {
    bucket       = "sandbox-state-bucket-001"
    key          = "secure-cicd-ecs-lab/terraform.tfstate"
    region       = "eu-west-1"
    profile      = "sandbox-user"
    encrypt      = true
    use_lockfile = true
  }
}
