variable "vpc_id" {
  description = "The ID of the VPC to use"
  type        = string
  default     = "vpc-08acb8e378d7416ac"
}

variable "subnet_id" {
  description = "The ID of the subnet where the instances will be launched"
  type        = string
  default     = "subnet-00b43076033f05567"
}

variable "instance_type" {
  description = "A list of instance types to use for each instance"
  type        = list(string)
  default     = ["t2.micro", "t2.micro", "t2.micro","t2.micro"]
}

variable "private_ips" {
  description = "A list of private IPs for the instances"
  type        = list(string)
  default     = ["172.32.2.8", "172.32.2.9", "172.32.2.10","172.32.2.17"]
}

variable "instance_names" {
  description = "A list of names for the instances"
  type        = list(string)
  default     = ["tomcat1-specific-reseller", "tomcat2-all-reseller", "Deployment-tomcat", "Multi-registrar-tomcat"]
}

variable "ami_id" {
  description = "The ID of the AMI to use for the instance"
  type        = string
  default     = "ami-0bcdb47863b39579f"
}

variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "us-east-2"
}

variable "key_name" {
  description = "The name of the key pair to use"
  type        = string
  default     = "DRkey"
}



variable "security_group_id" {
  description = "The ID of the existing security group"
  type        = string
  default     = "sg-02080a7b627d9ea68"  # Replace with your security group ID
}
