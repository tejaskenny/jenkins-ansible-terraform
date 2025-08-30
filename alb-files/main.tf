terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.7.0"
    }
  }
}

provider "aws" {
  region                  = var.aws_region
  shared_credentials_files = ["/home/centos/.aws/credentials"]
}

variable "public_subnet_ids" {
  type = list(string)
  default = [
    "subnet-02d5c7feadf78aba4",
    "subnet-0a84bd664549ffd0d"
  ]
}
#####################################################
resource "aws_security_group" "DR-loadBalancer-sg" {
  name   = "lb_sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

###############################################################
resource "aws_lb" "DR-application-alb" {
  name               = "DR-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.DR-loadBalancer-sg.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = true

  # access_logs {
  #  bucket  = aws_s3_bucket.lb_logs.id
  # prefix  = "test-lb"
  #enabled = true
  #}

  tags = {
    Environment = "production"
  }
}



resource "aws_lb_target_group" "tomcat1-specific-reseller" {
  name     = "atg-tomcat1-specific-reseller"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id



  health_check {
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"

  }
}




#########################  default listner rule ##################################
resource "aws_lb_listener" "listener_elb" {
  load_balancer_arn = aws_lb.DR-application-alb.arn
  port              = 80
  protocol          = "HTTP"



  default_action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }

}
###########################################################################
data "aws_instance" "specific-reseller" {
  filter {
    name   = "tag:Name"
    values = ["tomcat1-specific-reseller"] # replace with your instance name
  }
   filter {
    name = "instance-state-name"
    values = ["running"]
  }
}


resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.tomcat1-specific-reseller.arn
  target_id = data.aws_instance.specific-reseller.id
  port      = 80
}




###########

resource "aws_lb_target_group" "all-reseller" {
  name     = "atg-all-reseller"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id



  health_check {
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"

  }
}


data "aws_instance" "all-reseller" {
  filter {
    name   = "tag:Name"
    values = ["tomcat2-all-reseller"] # replace with your instance name
  }
 filter {
    name = "instance-state-name"
    values = ["running"]
  }
}


resource "aws_lb_target_group_attachment" "all-reseller-tomcat2" {
  target_group_arn = aws_lb_target_group.all-reseller.arn
  target_id        = data.aws_instance.all-reseller.id
  port             = 80
}

##########

resource "aws_lb_target_group" "view-domain" {
  name     = "atg-view-domain"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id



  health_check {
    interval            = 30
    path                = "/ConnectReseller/users/greeting"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"

  }
}


data "aws_instance" "view-domain" {
  filter {
    name   = "tag:Name"
    values = ["cr-view-domain"] # replace with your instance name
  }

   filter {
    name = "instance-state-name"
    values = ["running"]
  }
}


resource "aws_lb_target_group_attachment" "golang-view-domain" {
  target_group_arn = aws_lb_target_group.view-domain.arn
  target_id        = data.aws_instance.view-domain.id
  port             = 80
}

############################
resource "aws_lb_target_group" "multi-registrar" {
  name     = "atg-multi-registrar"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id



  health_check {
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"

  }
}


data "aws_instance" "Multi-registrar-tomcat" {
  filter {
    name   = "tag:Name"
    values = ["Multi-registrar-tomcat"] # replace with your instance name
  }
 filter {
    name = "instance-state-name"
    values = ["running"]
  }
}


resource "aws_lb_target_group_attachment" "multi-registrar" {
  target_group_arn = aws_lb_target_group.multi-registrar.arn
  target_id        = data.aws_instance.Multi-registrar-tomcat.id
  port             = 80
}





###################################################

resource "aws_lb_listener" "listner-443" {
  load_balancer_arn = aws_lb.DR-application-alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-2:010438477551:certificate/d26409ec-1907-4cdc-b36d-0eae8e7f4689"
    

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.all-reseller.arn
  }
}

################################################################

########################  View Domain   ==80 ###############################################

resource "aws_lb_listener_rule" "http-to-https-view-domain" {
  listener_arn = aws_lb_listener.listener_elb.arn
  priority     = 1

  action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }

  condition {
    path_pattern {
      values = [
        "/ConnectReseller/ESHOP/ViewDomain/*",
        "/ConnectReseller/ESHOP/ViewDomain"
      ]
    }
  }

  tags = {
    Name        = "view-domain"
    Environment = "Production"
  }
}

#################  View Domain listnser rule  http to https  ######
resource "aws_lb_listener_rule" "view-domain" {
  listener_arn = aws_lb_listener.listner-443.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.view-domain.arn
  }


  condition {
    path_pattern {
      values = [
        "/ConnectReseller/ESHOP/ViewDomain/*",
        "/ConnectReseller/ESHOP/ViewDomain"
      ]
    }
  }

  tags = {
    Name        = "view-domain"
    Environment = "Production"
  }
}




################## specific reseller http [80]  ######################

resource "aws_lb_listener_rule" "http-to-https-specific-reseller-7744-78" {
  listener_arn = aws_lb_listener.listener_elb.arn
  priority     = 2

  action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }

  condition {
    query_string {
      key   = "APIKey"
      value = "ZIOUhb0ykXBjn26"
    }

  }

  tags = {
    Name        = "specific-reseller-7744-78"
    Environment = "Production"
  }
}






################## specific reseller listner rule https [443]  ##########

resource "aws_lb_listener_rule" "specific-reseller-7744-78" {
  listener_arn = aws_lb_listener.listner-443.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tomcat1-specific-reseller.arn
  }


  condition {
    query_string {
      key   = "APIKey"
      value = "ZIOUhb0ykXBjn26"
    }
  }

  tags = {
    Name        = "specific-reseller-7744-78"
    Environment = "Production"
  }
}


############multi registrar logic 80 ########################
resource "aws_lb_listener_rule" "Multi-registrar-80" {
  listener_arn = aws_lb_listener.listener_elb.arn
  priority     = 3

  action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }

  condition {
    path_pattern {
      values = [
        "/MultipleRegistrar/*"
      ]
    }
  }

  tags = {
    Name        = "Multi-registrar"
    Environment = "Production"
  }
}

#################  Multi-registrar listnser rule  http to https  ######
resource "aws_lb_listener_rule" "Multi-registrar-443" {
  listener_arn = aws_lb_listener.listner-443.arn
  priority     = 3

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.multi-registrar.arn
  }


  condition {
    path_pattern {
      values = [
        "/MultipleRegistrar/*"
      ]
    }
  }

  tags = {
    Name        = "Multi-registrar"
    Environment = "Production"
  }
}
