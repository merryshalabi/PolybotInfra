aws_region          = "eu-west-2"
key_name            = "merryPolybotKey"
instance_type       = "t3.medium"
ami_id              = "ami-051fd0ca694aa2379"
availability_zones  = ["eu-west-2a", "eu-west-2b"]
public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
desired_capacity    = 2
min_size            = 0
max_size            = 4
acm_cert_arn        = "arn:aws:acm:eu-west-2:228281126655:certificate/c88b1bdf-2648-4508-bbc1-12115d868ede"



