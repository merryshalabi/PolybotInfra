variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones in the region"
  type        = list(string)
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for Ubuntu EC2"
  type        = string
}
variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "desired_capacity" {
  type        = number
  description = "Desired number of worker nodes in ASG"
  default     = 2
}

variable "min_size" {
  type        = number
  description = "Minimum number of worker nodes in ASG"
  default     = 1
}

variable "max_size" {
  type        = number
  description = "Maximum number of worker nodes in ASG"
  default     = 3
}
variable "acm_cert_arn" {
  description = "ARN of the ACM certificate for the HTTPS listener"
  type        = string
}
