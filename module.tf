provider "aws" {
#  access_key = "${var.access_key}"
#  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}


module "graylog" {
   source = "./modules/graylog"
   region = "${var.region}"
   env = "${var.env}"
   owner = "${var.owner}"
   graylog_ami = "${var.graylog_ami}"
   app_port = "${var.app_port}"
   alb_access_port = "${var.alb_access_port}"
   ssh_key = "${var.ssh_key}"
   subnet_public_ids = ["${element(var.subnet_public_ids,1)}", "${element(var.subnet_public_ids,2)}"]
   vpc_id = "${var.vpc_id}"
   r53zone_id = "${var.r53zone_id}"
   dns_name = "${var.dns_name}"
}
