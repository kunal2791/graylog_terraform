#!/bin/bash
configuration (){
secret_pass="$(echo -n password | sha256sum |awk '{print $1}')"
sudo sed -i "s/password_secret =/password_secret = $secret_pass /g" /etc/graylog/server/server.conf
sudo sed -i "s/root_password_sha2 =/root_password_sha2 = $secret_pass /g" /etc/graylog/server/server.conf
sudo sed -i "s/elasticsearch_shards = 4/elasticsearch_shards = 1/g" /etc/graylog/server/server.conf
IPADDY=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
mypubip="$(dig +short myip.opendns.com @resolver1.opendns.com)"
sudo sed -i -e 's|rest_listen_uri = http://127.0.0.1:9000/api/|#rest_listen_uri = http://$IPADDY:9000/api/|' /etc/graylog/server/server.conf
echo -e "web_listen_uri = http://$IPADDY:9000/" | sudo tee --append /etc/graylog/server/server.conf >> /dev/null
echo -e "rest_listen_uri = http://$IPADDY:9000/api/" | sudo tee --append /etc/graylog/server/server.conf >> /dev/null
#echo -e "rest_transport_uri = http://$mypubip:9000/api/" | sudo tee --append /etc/graylog/server/server.conf >> /dev/null
echo ${graylog_url}
echo "rest_transport_uri = http://${graylog_url}/api/" | sudo tee --append /etc/graylog/server/server.conf 
sudo chown -R elasticsearch.elasticsearch /var/lib/elasticsearch
}
service (){
sudo service graylog-server restart
sudo service elasticsearch restart
sudo service mongod restart
sudo chkconfig --add elasticsearch
sudo chkconfig --add graylog-server
sudo chkconfig --add mongod
}
rsyslog (){
echo -e "*.* @$IPADDY:1514;RSYSLOG_SyslogProtocol23Format" | sudo tee --append /etc/rsyslog.conf >> /dev/null
sudo service rsyslog restart
echo "we are all done"
echo "Browse to http://$mypubip:9000"
}
configuration
service
rsyslog
