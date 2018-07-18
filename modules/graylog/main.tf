#SG for GrayLog to allow only ssh and coustom graylog port
#Ingress rules allow traffic inside instance and egress traffic allows traffic from instance to outside world.

resource "aws_security_group" "graylog" {
  name = "Graylog"
  description = "sg for public instance"
  vpc_id = "${var.vpc_id}"

#Access_RULE
  ingress {
   from_port = 22
   to_port = 22
   protocol = "tcp"
   cidr_blocks = ["${var.jumpbox_ip}"]
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
        Name        = "${var.env}-graylog"
        Environment = "${lower(var.env)}"
        Owner = "${var.owner}"
}

   key_name = "${var.ssh_key}"
  #user_data = "${file("${path.module}/init.tpl")}"
   user_data = "${data.template_file.shell.rendered}"
  vpc_security_group_ids = ["${aws_security_group.graylog.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.graylog.id}"
  subnet_id = "${var.subnet_private_id}"
}

# ALB setup
#ALB creation to accept HTTPS request and route at graylog server.

resource "aws_alb" "graylog" {
  name            = "${var.env}-graylog-alb"
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
  name     = "${var.env}-graylog-tg"
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
  tags {
        Name        = "${var.env}-graylog"
        Environment = "${lower(var.env)}"
        Owner = "${var.owner}"
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
  protocol          = "HTTPS"
  certificate_arn   = "${var.certificate_arn}"
  ssl_policy        = "ELBSecurityPolicy-2015-05"

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

##This resouce willattach IAM role to graylog server
resource "aws_iam_instance_profile" "graylog" {
  name  = "graylog"
  role = "${aws_iam_role.graylog_role.name}"
}

##This resouce will create IAM role
resource "aws_iam_role" "graylog_role" {
  name = "${var.env}_graylog"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

##This resouce will atatch IAM inline policy to IAM role
resource "aws_iam_role_policy" "graylog_policy" {
  name = "${var.env}_graylog"
  role = "${aws_iam_role.graylog_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "autoscaling:Describe*",
                "cloudwatch:*",
                "logs:*",
                "sns:*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "iam:CreateServiceLinkedRole",
            "Resource": "arn:aws:iam::*:role/aws-service-role/events.amazonaws.com/AWSServiceRoleForCloudWatchEvents*",
            "Condition": {
                "StringLike": {
                    "iam:AWSServiceName": "events.amazonaws.com"
                }
            }
        }
    ]
}
EOF
}

#CloudWatch Alarm for graylog

resource "aws_cloudwatch_metric_alarm" "graylog" {
  alarm_name                = "${var.owner}-${var.env}-graylog_CpuUtilization"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "3"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "${var.env}-graylog-CPUUtilization"
  alarm_actions = [
    "${var.sns_topic}"]
  dimensions = {
  InstanceId = "${aws_instance.graylog.id}"
  }
}

resource "aws_cloudwatch_metric_alarm" "graylog-memory" {
  alarm_name                = "${var.owner}-${var.env}-graylog_MemoryUtilization"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "3"
  metric_name               = "MemoryUtilization"
  namespace                 = "System/Linux"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "${var.env}-graylog-MemoryUtilization"
  alarm_actions = [
    "${var.sns_topic}"]
  dimensions = {
  InstanceId = "${aws_instance.graylog.id}"
  }
}

resource "aws_cloudwatch_metric_alarm" "graylog-disk" {
  alarm_name                = "${var.owner}-${var.env}-graylog_DiskSpaceUtilization"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "3"
  metric_name               = "DiskSpaceUtilization"
  namespace                 = "System/Linux"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "${var.env}-graylog-DiskSpaceUtilization"
  alarm_actions = [
    "${var.sns_topic}"]
  dimensions = {
  Filesystem = "/dev/xvda1"
  MountPath = "/"
  InstanceId = "${aws_instance.graylog.id}"
  }
}

resource "aws_cloudwatch_metric_alarm" "graylog-secoundary-disk" {
  alarm_name                = "${var.owner}-${var.env}-graylog_SecoundaryDiskSpaceUtilization"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "3"
  metric_name               = "DiskSpaceUtilization"
  namespace                 = "System/Linux"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "${var.env}-graylog-SecoundaryDisk-DiskSpaceUtilization"
  alarm_actions = [
    "${var.sns_topic}"]
  dimensions = {
  Filesystem = "/dev/xvdb"
  MountPath = "/var/lib/elasticsearch"
  InstanceId = "${aws_instance.graylog.id}"
  }
}
 
  resource "aws_cloudwatch_metric_alarm" "graylog-alb-unhealthy-host" {
  alarm_name                = "${var.owner}-${var.env}-graylog_unhealthy-host"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "3"
  metric_name               = "UnHealthyHostCount"
  namespace                 = "AWS/ApplicationELB"
  period                    = "60"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "${var.env}-graylog-unhealthy-host"
  alarm_actions = [
    "${var.sns_topic}"]
  dimensions = {
    LoadBalancer = "${replace("${aws_alb.graylog.arn}", "/arn:.*?:loadbalancer\\/(.*)/", "$1")}"
  //TargetGroup =  "${replace("${aws_alb_target_group.graylog.arn}", "/arn:.*?:/\\/(.*)/", "$1")}"
  //LoadBalancer = "${aws_alb.graylog.name}"
   TargetGroup = "${aws_alb_target_group.graylog.arn_suffix}"
  }
}


