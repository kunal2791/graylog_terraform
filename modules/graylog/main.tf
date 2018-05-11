#SG for GrayLog to allow only ssh and coustom graylog port
#Ingress rules allow traffic inside instance and egress traffic allows traffic from instance to outside world.

resource "aws_security_group" "graylog" {
  name = "Graylog"
  description = "sg for public instance"
  vpc_id = "${var.vpc_id}"

#ssh_RULE
  ingress {
   from_port = 22
   to_port = 22
   protocol = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    from_port = 9000
    to_port = 9000
    protocol = "tcp"
    security_groups= ["${aws_security_group.alb.id}"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Public_ALB_sg
#ALB only allow to accept request with HTTPS "443".
 
resource "aws_security_group" "alb" {
  name = "ALB-graylog"
  description = "sg for Astrix-stage_ALB instance"
  vpc_id = "${var.vpc_id}"

#Access_RULE

  ingress {
   from_port = 443
   to_port = 443
   protocol = "tcp"
   cidr_blocks = ["194.161.216.0/22"]
  }

 egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
   from_port = 80
   to_port = 80
   protocol = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
  }

 egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Templete file to install graylog
#A Shell Script to mount volume and to configure graylog config file.

data "template_file" "shell" {
  template = "${file("${path.module}/init.tpl")}"

vars {
    graylog_url = "${var.dns_name}"
  }

}


#Graylog_instance launched under public instance 

resource "aws_instance" "graylog" {
  instance_type = "${var.graylog_instance_type}"
  monitoring = "true"
  ami = "${var.graylog_ami}"
   tags {
        Name        = "${var.owner}-${var.env}-graylog"
        Environment = "${lower(var.env)}"
        Owner = "${var.owner}"
}

   key_name = "${var.ssh_key}"
  #user_data = "${file("${path.module}/init.tpl")}"
   user_data = "${data.template_file.shell.rendered}"
  vpc_security_group_ids = ["${aws_security_group.graylog.id}"]
#  iam_instance_profile = "${aws_iam_instance_profile.new_profile.id}"
  subnet_id = "${element(var.subnet_public_ids,1)}"
}

# ALB setup
#ALB creation to accept HTTPS request and route at graylog server.

resource "aws_alb" "graylog" {
  name            = "Graylog-ALB"
  internal        = false
  security_groups = ["${aws_security_group.alb.id}"]
  subnets = ["${element(var.subnet_public_ids,1)}", "${element(var.subnet_public_ids,2)}"]
  enable_deletion_protection = true
  tags {
        Name        = "${var.env}-graylog"
        Environment = "${lower(var.env)}"
        Owner = "${var.owner}"
  }
}

#ALB target group

resource "aws_alb_target_group" "graylog" {
  name     = "graylog-tg"
  port     = "${var.app_port}"
  protocol = "${var.graylog_protocol}"
  vpc_id   = "${var.vpc_id}"
 # target_type = "instance"

health_check {
    interval            = 30
    path                = "${var.health_check_path}"
    port                = "${var.app_port}"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "${var.graylog_protocol}"
  }
}

#To attach graylog targetgroup to ALB

resource "aws_alb_target_group_attachment" "graylog-tg" {
  target_group_arn = "${aws_alb_target_group.graylog.arn}"
  target_id        = "${aws_instance.graylog.id}"
  port             = "${var.app_port}"

}

#stickiness {
#    type            = "alb_cookie"
#    cookie_duration = "${var.cookie_duration}"
#    enabled         = "${ var.cookie_duration == 1 ? false : true}"
#  }

#HTTPS Listners for ALB

resource "aws_alb_listener" "graylog_https" {
  load_balancer_arn = "${aws_alb.graylog.arn}"
  port              = "${var.alb_access_port}"
  protocol          = "HTTP"
#  certificate_arn   = "${var.certificate_arn}"
#  ssl_policy        = "ELBSecurityPolicy-2015-05"

  default_action {
    target_group_arn = "${aws_alb_target_group.graylog.id}"
    type             = "forward"
  }
}

#Route53 Record for graylog

resource "aws_route53_record" "graylog-r53" {
  zone_id = "${var.r53zone_id}"
 # name    = "${var.env}-graylog"
  name = "${var.dns_name}"
  type    = "A"
 # records = ["${aws_alb.graylog.dns_name}"]
 # ttl = "300"

  alias {
    name                   = "${aws_alb.graylog.dns_name}"
    zone_id                = "${aws_alb.graylog.zone_id}"
    evaluate_target_health = true
  }
}


