terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.7.0"
    }
  }
}

provider "aws" {
  region                   = var.aws_region
  shared_credentials_files = ["/home/centos/.aws/credentials"]
}



locals {
  public_key_path = "${path.module}/webairbetakey_pub"
}

resource "null_resource" "check_and_create_key_pair" {
  provisioner "local-exec" {
    command = <<EOT
      if ! /usr/local/bin/aws ec2 describe-key-pairs --key-names ${var.key_name} --output text --region ${var.aws_region}; then
        echo "Creating new key pair..."
        /usr/local/bin/aws ec2 import-key-pair --key-name ${var.key_name} --public-key-material fileb://${local.public_key_path} --region ${var.aws_region}
      else
        echo "Key pair already exists."
      fi
    EOT

    environment = {
      AWS_REGION = var.aws_region
    }
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "aws_key_pair" "DRkey" {
  count      = 0
  key_name   = var.key_name
  public_key = file(local.public_key_path)
}

resource "aws_instance" "first_instance" {
  count                       = length(var.private_ips)
  ami                         = var.ami_id
  instance_type               = var.instance_type[count.index]
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  private_ip                  = var.private_ips[count.index]
  associate_public_ip_address = true
  vpc_security_group_ids      = [var.security_group_id]


  root_block_device {
    volume_size           = 40
    volume_type           = "gp2"
    delete_on_termination = true
  }

  tags = {
    Name = var.instance_names[count.index]
  }

  depends_on = [null_resource.check_and_create_key_pair]
}

output "keyname" {
  value = var.key_name
}

output "instance_public_ip" {
  value = [for instance in aws_instance.first_instance : instance.public_ip]
}
