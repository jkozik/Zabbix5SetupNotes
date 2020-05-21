# Zabbix5SetupNotes
Follow instructions at https://www.zabbix.com/documentation/current/manual/installation/containers.
```
$ docker run --name mysql-server -t \
      -e MYSQL_DATABASE="zabbix" \
      -e MYSQL_USER="zabbix" \
      -e MYSQL_PASSWORD="zabbix_pwd" \
      -e MYSQL_ROOT_PASSWORD="root_pwd" \
      -d mysql:8.0.14 \
      --character-set-server=utf8 --collation-server=utf8_bin \
      --default-authentication-plugin=mysql_native_password
      
$ docker run --name zabbix-java-gateway -t \
      --restart unless-stopped \
      -d zabbix/zabbix-java-gateway:latest
      
$ docker run --name zabbix-server-mysql -t \
      -e DB_SERVER_HOST="mysql-server" \
      -e MYSQL_DATABASE="zabbix" \
      -e MYSQL_USER="zabbix" \
      -e MYSQL_PASSWORD="zabbix_pwd" \
      -e MYSQL_ROOT_PASSWORD="root_pwd" \
      -e ZBX_JAVAGATEWAY="zabbix-java-gateway" \
      --link mysql-server:mysql \
      --link zabbix-java-gateway:zabbix-java-gateway \
      -p 10051:10051 \
      --restart unless-stopped \
      -d zabbix/zabbix-server-mysql:latest
      

$ docker run --name zabbix-web-apache-mysql -t \
      -e DB_SERVER_HOST="mysql-server" \
      -e MYSQL_DATABASE="zabbix" \
      -e MYSQL_USER="zabbix" \
      -e MYSQL_PASSWORD="zabbix_pwd" \
      -e MYSQL_ROOT_PASSWORD="root_pwd" \
      --link mysql-server:mysql \
      --link zabbix-server-mysql:zabbix-server \
      -p 80:8080 \
      --restart unless-stopped \
      -d zabbix/zabbix-web-apache-mysql:latest
```
To be worked: zabbix-agent
```
$ docker run --name some-zabbix-agent \
       -e ZBX_HOSTNAME="some-hostname" \
       -e ZBX_SERVER_HOST="some-zabbix-server" \
       -d zabbix/zabbix-agent:tag
       
$ docker run --name zabbix-agent \
       -e ZBX_HOSTNAME="linode2.kozik.net" \
       -e ZBX_SERVER_HOST="127.0.0.1" \
       -d zabbix/zabbix-agent:centos-5.0-latest
 
 --or--
 
$ docker run --name some-zabbix-agent --link some-zabbix-server:zabbix-server -d zabbix/zabbix-agent:latest
$ docker run --name zabbix-agent --link zabbix-server-mysql:zabbix-server -d zabbix/zabbix-agent:centos-5.0-latest
```

Continue troubleshooting at https://hub.docker.com/r/digiapulssi/docker-zabbix-agent/

