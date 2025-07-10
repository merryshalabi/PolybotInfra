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
s3_bucket_name_dev     = "merry-dev-bucket"
sqs_queue_arn_dev       = "arn:aws:sqs:eu-west-2:228281126655:polybot-chat-messages-merry-dev"
dynamodb_table_arn_dev = "arn:aws:dynamodb:eu-west-2:228281126655:table/PredictionsDev-merry"
s3_bucket_name_prod    = "merry-polybot-images"
sqs_queue_arn_prod       = "arn:aws:sqs:eu-west-2:228281126655:polybot-chat-messages-merry"
dynamodb_table_arn_prod = "arn:aws:dynamodb:eu-west-2:228281126655:table/PredictionsProd-merry"



