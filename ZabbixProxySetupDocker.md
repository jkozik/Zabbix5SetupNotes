# Zabbix Proxy Setup Docker
I am putting the proxy in a container because I am concerned that my Centos 7 systems are running with old PHP versions and a contain will be easier that klugding a PHP upgrade.

## Create mysql database.  
Follow the same template as setting up the zabbix-server.  
```
$ docker run --name mysql-server -t \
      -e MYSQL_DATABASE="zabbix" \
      -e MYSQL_USER="zabbix" \
      -e MYSQL_PASSWORD="zabbix_pwd" \
      -e MYSQL_ROOT_PASSWORD="root_pwd" \
      -d mysql:8.0.14 \
      --character-set-server=utf8 --collation-server=utf8_bin \
      --default-authentication-plugin=mysql_native_password
```
## Install zabbix-proxy
Again, following the same template as a zabbix-agent. Note that a zabbix_proxy.psk needs to be created and put in the correct host directory.
```
$ docker run --name zabbix-proxy-mysql -p 10061:10061  \
   -e DB_SERVER_HOST="mysql-server" \
   -e MYSQL_DATABASE="zabbix" \
   -e MYSQL_USER="zabbix" \
   -e MYSQL_PASSWORD="zabbix_pwd" \
   -e MYSQL_ROOT_PASSWORD="root_pwd" \
   -e ZBX_HOSTNAME=Dell2Proxy176 \
   -e ZBX_SERVER_HOST=linode2.kozik.net \
   -e ZBX_TLSPSKIDENTITY="PSK 001"  \
   -v /var/lib/zabbix/enc:/var/lib/zabbix/enc \
   -e ZBX_TLSPSKFILE=zabbix_agentd.psk   \
   -e ZBX_SERVER_HOST="linode2.kozik.net"  \
   -e ZBX_TLSCONNECT="psk" \
   -e ZBX_TLSACCEPT="psk" \
   --link mysql-server:mysql \
   -d zabbix/zabbix-proxy-mysql:centos-5.0-latest
```


