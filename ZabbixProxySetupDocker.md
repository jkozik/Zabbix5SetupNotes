# Zabbix Proxy Setup Docker
I am putting the proxy in a container because I am concerned that my Centos 7 systems are running with old PHP versions and a container will be easier that klugding a PHP upgrade. For my most recent proxy installation, I decided to dedicate a VirtualBox VM, isolating the proxy from everything else going on.  Maybe someday, I'll put the proxy on my pfsense home router, but not now.

## Create mysql database.  
Follow the same template as setting up the zabbix-server.  
```
$ docker run --name mysql-server -t \
      -e MYSQL_DATABASE="zabbix" \
      -e MYSQL_USER="zabbix" \
      -e MYSQL_PASSWORD="zabbix_pwd" \
      -e MYSQL_ROOT_PASSWORD="root_pwd" \
      -d mysql:8.0.18 \
      --character-set-server=utf8 --collation-server=utf8_bin \
      --default-authentication-plugin=mysql_native_password
```
## Install zabbix-proxy
Again, following the same template as a zabbix-agent. Note that a zabbix_proxy.psk needs to be created and put in the correct host directory.
```
$ docker run --name zabbix-proxy-mysql -p 10050:10050  \
   -e DB_SERVER_HOST="mysql-server" \
   -e MYSQL_DATABASE="zabbix" \
   -e MYSQL_USER="zabbix" \
   -e MYSQL_PASSWORD="zabbix_pwd" \
   -e MYSQL_ROOT_PASSWORD="root_pwd" \
   -e ZBX_HOSTNAME=Dell2Proxy175 \
   -e ZBX_SERVER_HOST=linode2.kozik.net \
   -e ZBX_TLSPSKIDENTITY="PSK 001"  \
   -v /var/lib/zabbix/enc:/var/lib/zabbix/enc \
   -e ZBX_TLSPSKFILE=zabbix_agentd.psk   \
   -e ZBX_SERVER_HOST="linode2.kozik.net"  \
   -e ZBX_TLSCONNECT="psk" \
   -e ZBX_TLSACCEPT="psk" \
   --link mysql-server:mysql \
   -d zabbix/zabbix-proxy-mysql:centos-5.0-latest
$ docker logs zabbix-proxy-mysql  # check that it connects with the mysql server and receives informatino from the zabbix server
```
## Zabbix Agent for the VM hosting the proxy server
So this proxy server covers about 10 home devices, but I still want to monitor the status of this particular VM, so I must also setup a zabbix agent for this VM.   I set it up using docker.  Here's the command I used to install it.
```
$ docker run --name zabbix-agent -p 10090:10050 \
   -v /var/lib/zabbix/enc:/var/lib/zabbix/enc \
   -e ZBX_TLSPSKIDENTITY="PSK 001"  \
   -e ZBX_TLSPSKFILE=zabbix_agentd.psk  \
   -e ZBX_SERVER_HOST="linode2.kozik.net" \
   -e ZBX_TLSCONNECT="psk" \
   -e ZBX_TLSACCEPT="psk" \
   -e ZBX_SERVER_PORT="10090" \
   -d zabbix/zabbix-agent:centos-5.0-latest
$ docker logs -f zabbix-agent      # verify that it appears to be working
```
The above script creates a passive zabbix agent for this host.  Because it is passive, it communicates with the zabbix server like a web server:  I must open the port 10090:10091 through the firewall.  I set this rule in my pfsense router (not shown here).  Also, I need to verify that the VM has these ports open as well.  In my case, I am using Alpine linux and the firewall appears to be off, but in Centos7, I would need to run the firewall-cmd to open the ports. 

On the zabbix-server front end web interface, this VM needs to be added as a new host, select a zabbix server passive template and use the public IP address.  The host needs to point to port 10090.

