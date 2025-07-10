
resource "aws_security_group" "control_plane_sg" {
  name        = "control-plane-sg"
  description = "Allow SSH and Kubernetes API"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow BGP (Calico) from VPC"
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Allow all traffic from VPC (pods, DNS, etc)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Allow worker nodes to reach control-plane (e.g. kubelet)"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ssm_role" {
  name = "k8s-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "put_parameter_policy" {
  name        = "AllowPutParameter"
  description = "Allow EC2 to put kubeadm join command into SSM Parameter Store"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:PutParameter",
          "ec2:DescribeInstances"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "put_parameter_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.put_parameter_policy.arn
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "k8s-control-plane-instance-profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_instance" "control_plane" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id            = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.control_plane_sg.id]
  key_name               = var.key_name
  associate_public_ip_address = true
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name

  user_data = file("${path.module}/control_plane_user_data.sh")

  tags = {
    Name = "control-plane"
  }
}

resource "aws_launch_template" "worker" {
  name_prefix   = "k8s-worker"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_instance_profile.name
  }

  user_data = base64encode(file("${path.module}/user_data_worker.sh"))

    network_interfaces {
      associate_public_ip_address = true
      security_groups = [
        aws_security_group.control_plane_sg.id,
        aws_security_group.worker_sg.id
      ]
    }


  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "k8s-worker"
    }
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

}

resource "aws_autoscaling_group" "worker_asg" {
  name                      = "k8s-worker-asg"
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  health_check_type         = "EC2"
  force_delete              = true

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "k8s-worker"
    propagate_at_launch = true
  }


  lifecycle {
    create_before_destroy = true
  }
  vpc_zone_identifier = var.subnet_ids

}

resource "aws_security_group" "worker_sg" {
  name        = "worker-sg"
  description = "Allow traffic for K8s worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow control-plane to access kubelet"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.control_plane_sg.id]
  }

  ingress {
    description = "Allow BGP (Calico) from VPC"
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description     = "Allow LB to access Ingress NodePort (31183)"
    from_port       = 31183
    to_port         = 31183
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  ingress {
    description = "Allow NodePort range"
    from_port   = 31741
    to_port     = 31741
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "Allow all traffic from within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_lb" "k8s_lb" {
  name               = "k8s-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = var.subnet_ids

  tags = {
    Name = "k8s-lb"
  }
}

resource "aws_security_group" "lb_sg" {
  name        = "k8s-lb-sg"
  description = "Allow inbound HTTPS to LB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "allow_worker_to_worker_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.worker_sg.id
  source_security_group_id = aws_security_group.worker_sg.id
  description       = "Allow all traffic between worker nodes"
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.k8s_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_cert_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_nodeport_tg.arn
  }
}


resource "aws_lb_target_group" "nginx_nodeport_tg" {
  name        = "nginx-nodeport-tg"
  port        = 31183
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/healthz"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}


resource "aws_autoscaling_attachment" "nginx_asg_lb_attachment" {
  autoscaling_group_name = aws_autoscaling_group.worker_asg.name
  lb_target_group_arn   = aws_lb_target_group.nginx_nodeport_tg.arn
}

resource "aws_iam_policy" "s3_bot_policy" {
  name        = "ImageBotS3Access"
  description = "Allow bot to upload and download files to S3 bucket"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "s3:PutObject",
        "s3:GetObject"
      ],
      Resource = "arn:aws:s3:::${var.s3_bucket_name}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_bot_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.s3_bot_policy.arn
}
resource "aws_iam_policy" "yolo_sqs_policy" {
  name        = "YoloSQSAccess"
  description = "Allow YOLO service to read from SQS queue"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = "${var.sqs_queue_arn}"
      }
    ]
  })
}

resource "aws_iam_policy" "yolo_dynamodb_policy" {
  name        = "YoloDynamoDBAccess"
  description = "Allow YOLO service to read/write DynamoDB"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        Resource = "${var.dynamodb_table_arn}"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "yolo_sqs_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.yolo_sqs_policy.arn
}

resource "aws_iam_role_policy_attachment" "yolo_dynamodb_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.yolo_dynamodb_policy.arn
}


