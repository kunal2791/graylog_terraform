output "graylog_sg" {
   value = "${aws_security_group.graylog.id}"
}
output "alb_sg" {
   value = "${aws_security_group.alb.id}"
}
output "graylog_instance" {
   value = "${aws_instance.graylog.id}"
}
output "graylog_alb" {
   value = "${aws_alb.graylog.id}"
}
output "alb_tg" {
   value = "${aws_alb_target_group.graylog.id}"
}
output "alb_attachment" {
   value = "${aws_alb_target_group_attachment.graylog-tg.id}"
}
output "alb_listener" {
   value = "${aws_alb_listener.graylog_https.id}"
}
output "route53_graylog" {
   value = "${aws_route53_record.graylog-r53.id}"
}
