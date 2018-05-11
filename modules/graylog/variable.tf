variable "ssh_key" {
   default = ""
}
variable "graylog_instance_type" {
  description = "AWS instance size ex. t2.micro t2.medium etc."
  default = "t2.medium"
}
variable "graylog_ami" {
  description = "graylog image id"
#  default = ""
}
variable "vpc_id" {
  description = "graylog VPC id"
}
variable "gurgaon_ip" {
   default = "194.161.216.0/22"
}
variable "owner" {
   description = "owner name ex. project name"
}
variable "env" {
   description = "project environment name ex. stage prod. demo"
}
variable "health_check_path" {
   description = "path to check health of instance on instance"
   default = "/"
}
variable "graylog_protocol" {
   default = "HTTP"
}
variable "cookie_duration" {
   default = "1"
}
#variable "certificate_arn" {
#   description = "add certificate ARN for HTTPS"
#   default = ""
#}
variable "r53zone_id" {
    description = "Zone ID of your route53 to create A record"
    default = ""
}
variable "region" {
    default = ""
}
variable "subnet_public_ids" {
    type = "list"
    default = [""]
}
variable "dns_name" {
   default = ""
}
variable "app_port" {
   default = ""
}
variable "alb_access_port" {
   default = ""
}
