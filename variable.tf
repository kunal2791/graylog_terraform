#variable "access_key" {}
#variable "secret_key" {}
variable "region" {
    default = ""
}
variable "env" {
    default = ""
}
variable "vpc_id" {
    default = ""
}
variable "owner" {
    default = ""
}
#variable "subnet_public_id" {
#  description = "pubilc subnet id to launch graylog and to map it with ALB"
#  default = ""
#}
#variable "subnet_public2_id" {
#   description = "secound public subnet id to map with ALB"
#   default = ""
#}
#variable "public_subnet_ids" {
#}
variable "r53zone_id" {
    description = "Zone ID of your route53 to create A record"
    default = ""
}
variable "ssh_key" {
    default = ""
}
variable "graylog_ami" {
  description = "graylog image id"
  default = ""
}
variable "dns_name" {
   default = ""
}
variable "subnet_public_ids" {
   type = "list"
}
variable "app_port" {
   default = ""
}
variable "alb_access_port" {
   default = ""
}
