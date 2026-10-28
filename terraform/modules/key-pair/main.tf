# Generates an RSA key, registers the public half with EC2 and writes the
# private half to disk for Ansible. The private key is also in Terraform state,
# which is why the state bucket is encrypted and private.

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = tls_private_key.this.public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.this.private_key_pem
  filename        = var.private_key_path
  file_permission = "0400"
}
