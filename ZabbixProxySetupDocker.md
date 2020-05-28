# Zabbix Proxy Setup Docker
I am putting the proxy in a container because I am concerned that my Centos 7 systems are running with old PHP versions and a contain will be easier that klugding a PHP upgrade.
```
$ docker run --name zabbix-agent -p 10070:10050 
   -v /var/lib/zabbix/enc:/var/lib/zabbix/enc 
   -e ZBX_TLSPSKIDENTITY="PSK 001"  
   -e ZBX_TLSPSKFILE=zabbix_agentd.psk  
   -e ZBX_SERVER_HOST="linode2.kozik.net" 
   -e ZBX_TLSCONNECT="psk" 
   -e ZBX_TLSACCEPT="psk" 
   -e ZBX_SERVER_PORT="10070" 
   -d zabbix/zabbix-agent:centos-5.0-latest
```

```
$ docker run --name mysql-server -t \
      -e MYSQL_DATABASE="zabbix" \
      -e MYSQL_USER="zabbix" \
      -e MYSQL_PASSWORD="zabbix_pwd" \
      -e MYSQL_ROOT_PASSWORD="root_pwd" \
      -d mysql:8.0.14 \
      --character-set-server=utf8 --collation-server=utf8_bin \
      --default-authentication-plugin=mysql_native_password



$ docker run --name zabbix-proxy-mysql -p 10060:10050  \
   -e DB_SERVER_HOST="mysql-server" \
   -e MYSQL_USER="zabbixuser" -e MYSQL_PASSWORD="zabbixpw"  \
   -e ZBX_HOSTNAME=Dell2Proxy176 \
   -e ZBX_SERVER_HOST=linode2.kozik.net \
   -e ZBX_TLSPSKIDENTITY="PSK 001"  \
   -v /var/lib/zabbix/enc:/var/lib/zabbix/enc \
   -e ZBX_TLSPSKFILE=zabbix_agentd.psk   \
   -e ZBX_SERVER_HOST="linode2.kozik.net"  \
   -e ZBX_TLSCONNECT="psk" \
   -e ZBX_TLSACCEPT="psk" \
   -e ZBX_SERVER_PORT="10060" \
   --link mysql-server:mysql \
   -d zabbix/zabbix-proxy-mysql:centos-5.0-latest
```


