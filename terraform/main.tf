locals {

  Environment     = "dev"
  Terraform       = "true"
  ami             = "ami-0530ca8899fac469f"       							                                              	    ## Base image of Ubuntu 20.04  ##
  instance_type   = "t3a.small"
  key_name        = "rachit1"                                              
  Owner           = "RACHIT"
  name            = "rachit"
  region          = "us-west-2"
 ## pritunl_script  = "pritunl.sh"                   				                                              				     ## SCRIPT TO LAUNCH PRITUNL SERVER ##
  ##certificate_arn = "arn:aws:acm:us-west-2:421320058418:certificate/73b9c44b-3865-4f0a-b508-dc118857ae2e"            ## Certificate for ALB ##
  image_id        = "ami-080beefdfafc6e5c4"                                                                          ## CUSTOM IMAGE BUILT USING PACKER  ##
 ## script_mongo    = "mongo_install.sh"                                                                               ## SCRIPT TO INSTALL MONGO ##
  name_prefix     = "rachi"
  host_headers    = "rachitvpn.rtd.squareops.co.in"

}


## CREATING VPN  ##


module "rachit-pritunl" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "~> 3.0"
  name                   = local.name
  ami                    = local.ami
  instance_type          = local.instance_type
  key_name               = local.key_name
  vpc_security_group_ids = [aws_security_group.pritunl-sg.id]
  subnet_id              = element(module.vpc.public_subnets, 0)
  user_data              = filebase64("pritunl.sh")

  tags = {
    Terraform   = local.Terraform
    Environment = local.Environment
  }
}


## security group for pritunl ##

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}


resource "aws_security_group" "pritunl-sg" {
  name   = "Pritunl-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }
  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "TLS from VPC"
    from_port   = 19103
    to_port     = 19103
    protocol    = "udp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name  = local.name
    Owner = local.Owner
  }
}








## CREATING VPC  ##



module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.18.1"

  name = "local.name"
  cidr = "10.0.0.0/16"

  azs             = ["${local.region}a", "${local.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  single_nat_gateway = true
  enable_nat_gateway = true

  tags = {
    Terraform   = local.Terraform
    Environment = local.Environment
    Owner       = "${local.name}-vpc"
  }
}




## CREATING ALB##


module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name               = "${local.name}-alb"
  load_balancer_type = "application"

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = [resource.aws_security_group.rachit-sg-lb.id]

  target_groups = [
    {
      name_prefix          = local.name_prefix
      backend_protocol     = "HTTP"
      backend_port         = 3000
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200,404"

      }
    },
    {
      name_prefix          = "vpn"
      backend_protocol     = "HTTPS"
      backend_port         = 443
      target_type          = "ELB"
      deregistration_delay = 10
      target_type          = "instance"
      targets = {
        my_target = {
          target_id = module.rachit-pritunl.id
          port      = 443
        }
      }
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/login"
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200,404"
      }
    }
  ]
  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = "arn:aws:acm:us-west-2:421320058418:certificate/73b9c44b-3865-4f0a-b508-dc118857ae2e"
      target_group_index = 0
    }
  ]
  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]
  tags = {
    Environment = local.Environment
    Name        = "${local.name}-tg"
  }
  https_listener_rules = [
    {
      https_listener_index = 0

      actions = [{
        type               = "forward"
        target_group_index = 1
      }]

      conditions = [{
        host_headers = ["local.host_headers"]
      }]
    }
  ]
}


## SG for ALB  ##


resource "aws_security_group" "rachit-sg-lb" {
  name        = "${local.name}-sg-lb"
  description = "Allow TLS inbound and outbund traffic"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${local.name}-sg-lb"
    Owner       = local.name
    Environment = local.Environment
    Terraform   = local.Terraform
  }
}


## CREATING ASG ##


module "rachit-asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  name = "${local.name}-asg-node"

  min_size                  = 2
  max_size                  = 5
  desired_capacity          = 2
  wait_for_capacity_timeout = 0
  health_check_type         = "ELB"
  vpc_zone_identifier       = module.vpc.private_subnets

  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay       = 600
      checkpoint_percentages = [35, 70, 100]
      instance_warmup        = 300
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }

## Launch template ##


  launch_template_name        = "${local.name}-lt-node"
  launch_template_description = "Launch template example"
  update_default_version      = true

  image_id                  = local.image_id
  instance_type             = local.instance_type
  key_name                  = local.key_name
  ebs_optimized             = true
  enable_monitoring         = true
  target_group_arns         = [module.alb.target_group_arns[0]]
  iam_instance_profile_name = "rachit-codedeploy"
  security_groups           = [aws_security_group.rachit-sg-node.id]

  tags = {
    Environment = local.Environment
    Owner       = local.Owner
  }
}

## Scaling Policy ##

resource "aws_autoscaling_policy" "asg-policy" {
  count                     = 1
  name                      = "${local.name}asg-cpu-policy"
  autoscaling_group_name    = module.rachit-asg.autoscaling_group_name
  estimated_instance_warmup = 60
  policy_type               = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}

## Security Group for NodeApp Instance  ##

resource "aws_security_group" "rachit-sg-node" {
  name        = "${local.name}-sg-node"
  description = "Allow TLS inbound and outbund traffic"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description     = "TLS from VPC"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.pritunl-sg.id]
    #cidr_blocks      = [module.vpc.vpc_cidr_block]
  }
  ingress {
    description     = "TLS from VPC"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.rachit-sg-lb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${local.name}-sg-node"
    Owner       = local.Owner
    Environment = local.Environment
    Terraform   = local.Terraform
  }
}




## LAUNCHING INSTANCES FOR MONGODB  ##



module "rachit_ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  for_each = toset(["mongo0", "mongo1", "mongo2"])

  name = "${local.name}-${each.key}"

  ami                    = local.ami
  instance_type          = local.instance_type
  key_name               = local.key_name
  monitoring             = true
  vpc_security_group_ids = [resource.aws_security_group.rachit-sg-mongo.id]
  subnet_id              = module.vpc.private_subnets[0]

  user_data = filebase64("mongo_install.sh")

  tags = {
    Owner       = local.Owner
    Environment = local.Environment
    Terraform   = local.Terraform

  }
}

## Security Group of Mongo Instances  ##

resource "aws_security_group" "rachit-sg-mongo" {
  name        = "${local.name}-sg-mongo"
  description = "Allow TLS inbound and outbund traffic"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description     = "TLS from VPC"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.pritunl-sg.id]
    #cidr_blocks      = [module.vpc.vpc_cidr_block]
  }
  ingress {
    description     = "TLS from VPC"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.rachit-sg-node.id]
    self            = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name        = "${local.name}-sg-mongo"
    Owner       = local.Owner
    Environment = local.Environment
    Terraform   = local.Terraform
  }
}
