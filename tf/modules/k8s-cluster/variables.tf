variable "vpc_id" {
  type        = string
  description = "VPC ID for the instance"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of Subnet IDs for control plane and ASG"
}


variable "key_name" {
  type        = string
  description = "EC2 key pair name"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for EC2"
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
