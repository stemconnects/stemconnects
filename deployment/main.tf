//# configures terraform to use the AWS provider
//terraform {
//  required_providers {
//    aws = {
//      source  = "hashicorp/aws"
//      version = "~> 4.16"
//    }
//  }
//
//  required_version = ">= 1.2.0"
//}
//
//# configures the AWS provider
//provider "aws" {
//  region = "us-east-1"
//}
//
//# adopt the default role created by AWS to run the task under
//data "aws_iam_role" "ecs_task_execution_role" {
//  name = "ecsTaskExecutionRole"
//}
//
//# create a security group
//#
//# this is used to allow network traffic to reach our containers
//resource "aws_security_group" "stemconnects_security_group" {
//  name = "stemconnects-security-group"
//  ingress {
//    from_port        = 80
//    to_port          = 80
//    protocol         = "tcp"
//    cidr_blocks      = ["0.0.0.0/0"]
//    ipv6_cidr_blocks = ["::/0"]
//  }
//  ingress {
//    from_port        = 443
//    to_port          = 443
//    protocol         = "tcp"
//    cidr_blocks      = ["0.0.0.0/0"]
//    ipv6_cidr_blocks = ["::/0"]
//  }
//  ingress {
//    from_port        = 8080
//    to_port          = 8080
//    protocol         = "tcp"
//    cidr_blocks      = ["0.0.0.0/0"]
//    ipv6_cidr_blocks = ["::/0"]
//  }
//  egress {
//    from_port        = 0
//    to_port          = 0
//    protocol         = "-1"
//    cidr_blocks      = ["0.0.0.0/0"]
//    ipv6_cidr_blocks = ["::/0"]
//  }
//}
//
//data "aws_vpc" "default_vpc" {
//  default = true
//}
//
//data "aws_subnets" "stemconnects_subnets" {
//  filter {
//    name   = "vpc-id"
//    values = [data.aws_vpc.default_vpc.id]
//  }
//}
//
//data "aws_subnet" "stemconnects_subnet" {
//  for_each = toset(data.aws_subnets.stemconnects_subnets.ids)
//  id       = each.value
//  depends_on = [
//    data.aws_subnets.stemconnects_subnets
//  ]
//}
//
//# define a task for the frontend webserver
//resource "aws_ecs_task_definition" "stemconnects_frontend_task_definition" {
//  family                   = "stemconnects-frontend-task-definition"
//  task_role_arn            = data.aws_iam_role.ecs_task_execution_role.arn
//  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
//  network_mode             = "bridge"
//  requires_compatibilities = ["EC2"]
//  cpu                      = 256
//  memory                   = 256
//
//  container_definitions = jsonencode([
//    {
//      name      = "stemconnects-frontend"
//      image     = "800636676873.dkr.ecr.us-east-1.amazonaws.com/stemconnects-frontend"
//      essential = true
//      command   = ["nginx", "-g", "daemon off;"]
//      portMappings = [
//        {
//          containerPort = 80
//          hostPort      = 80
//        }
//      ]
//    }
//  ])
//}
//
//# define a task for the backend
//resource "aws_ecs_task_definition" "stemconnects_backend_task_definition" {
//  family                   = "stemconnects-backend-task-definition"
//  task_role_arn            = data.aws_iam_role.ecs_task_execution_role.arn
//  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
//  network_mode             = "bridge"
//  requires_compatibilities = ["EC2"]
//  cpu                      = 256
//  memory                   = 256
//
//  container_definitions = jsonencode([
//    {
//      name      = "stemconnects-backend"
//      image     = "800636676873.dkr.ecr.us-east-1.amazonaws.com/stemconnects-backend"
//      essential = true
//      portMappings = [
//        {
//          containerPort = 8080
//          hostPort      = 8080
//        }
//      ]
//    }
//  ])
//}
//
//# create a load balancer to distribute traffic to the tasks described below
//resource "aws_lb" "stemconnects_lb" {
//  name               = "stemconnects-lb"
//  internal           = false
//  load_balancer_type = "application"
//  security_groups    = [aws_security_group.stemconnects_security_group.id]
//  subnets            = [for s in data.aws_subnet.stemconnects_subnet : s.id]
//}
//
//# create a frontend target group for the load balancer described above
//resource "aws_lb_target_group" "stemconnects_frontend_lb_target_group" {
//  name        = "stemconnects-frontend-lb-tg"
//  port        = 80
//  protocol    = "HTTP"
//  vpc_id      = data.aws_vpc.default_vpc.id
//  target_type = "instance"
//  health_check {
//    port = 80
//  }
//  depends_on = [
//    aws_lb.stemconnects_lb
//  ]
//}
//
//# create a backend target group for the load balancer described above
//resource "aws_lb_target_group" "stemconnects_backend_lb_target_group" {
//  name        = "stemconnects-backend-lb-tg"
//  port        = 8080
//  protocol    = "HTTP"
//  vpc_id      = data.aws_vpc.default_vpc.id
//  target_type = "instance"
//  health_check {
//    path = "/api/test"
//    port = 8080
//  }
//  depends_on = [
//    aws_lb.stemconnects_lb
//  ]
//}
//
//# load balancer endpoint
//resource "aws_lb_listener" "stemconnects_lb_listener" {
//  load_balancer_arn = aws_lb.stemconnects_lb.arn
//  port              = "443"
//  protocol          = "HTTPS"
//  ssl_policy        = "ELBSecurityPolicy-2016-08"
//  certificate_arn   = data.aws_acm_certificate.stemconnects_acm_certificate.arn
//
//  default_action {
//    type             = "forward"
//    target_group_arn = aws_lb_target_group.stemconnects_frontend_lb_target_group.arn
//  }
//}
//
//# load balancer listener rule for the backend
//resource "aws_lb_listener_rule" "stemconnects_lb_listener_rule" {
//  listener_arn = aws_lb_listener.stemconnects_lb_listener.arn
//  priority     = 1
//
//  action {
//    type             = "forward"
//    target_group_arn = aws_lb_target_group.stemconnects_backend_lb_target_group.arn
//  }
//
//  condition {
//    path_pattern {
//      values = ["/api/*"]
//    }
//  }
//}
//
//# define a service, running an instance of the frontend webserver
//resource "aws_ecs_service" "stemconnects_frontend_ecs_service" {
//  name                   = "stemconnects-frontend-ecs-service"
//  enable_execute_command = true
//  launch_type            = "EC2"
//  cluster                = aws_ecs_cluster.stemconnects_cluster.id
//  task_definition        = aws_ecs_task_definition.stemconnects_frontend_task_definition.id
//  desired_count          = 1
//  deployment_maximum_percent = 100
//  deployment_minimum_healthy_percent = 0
//  load_balancer {
//    target_group_arn = aws_lb_target_group.stemconnects_frontend_lb_target_group.arn
//    container_name   = "stemconnects-frontend"
//    container_port   = 80
//  }
//}
//
//# define a service, running an instance of the backend
//resource "aws_ecs_service" "stemconnects_backend_ecs_service" {
//  name                   = "stemconnects-backend-ecs-service"
//  enable_execute_command = true
//  launch_type            = "EC2"
//  cluster                = aws_ecs_cluster.stemconnects_cluster.id
//  task_definition        = aws_ecs_task_definition.stemconnects_backend_task_definition.id
//  desired_count          = 1
//  deployment_maximum_percent = 100
//  deployment_minimum_healthy_percent = 0
//  load_balancer {
//    target_group_arn = aws_lb_target_group.stemconnects_backend_lb_target_group.arn
//    container_name   = "stemconnects-backend"
//    container_port   = 8080
//  }
//}
