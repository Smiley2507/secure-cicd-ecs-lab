module "ecr" {
  source = "./modules/ecr"

  name                 = var.app_name
  keep_image_count     = 10
  untagged_expiry_days = 1
}
