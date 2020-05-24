# Zabbix 5.0 Setup Notes
## Zabbix Server setup using docker
The server that runs my Zabbix server is called linode2.kozik.net.  On it, I install a zabbix-server.  Because the it is runnong on a host and all hosts require an agent, I also install a zabbix server.  The zabbix-server keeps a deep time series data base in mysql; I install that too.  Follow instructions at https://www.zabbix.com/documentation/current/manual/installation/containers.
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
Next, on the same host as the zabbix-server, install a zabbix-agent and link it to the zabbix-server. Note the docker run command uses the --link option. Useful link- https://blog.zabbix.com/zabbix-agent-active-vs-passive/9207/ and https://hub.docker.com/r/zabbix/zabbix-agent
```
$ docker run --name zabbix-agent --link zabbix-server-mysql:zabbix-server -d zabbix/zabbix-agent:centos-5.0-latest
$ docker container inspect zabbix-agent | grep IPAddress  # Get the IP Address of the zabbix-agent
```
From a web browser go to the zabbix web page: http://linode2.kozik.net. Login with the default username/password and go to the configuration for the Zabbix Server.  Add a new host; for its interfaces/Agent field, enter the IP Address from above. Soon the ZBX icon should turn green.

One can force the server configuration refresh by getting a bash prompt in the zabbix-server container and running a zabbix_server command.
```
$ docker exec -it zabbix-server /bin/bash
  $ zabbix_server -R config_cache_reload
```
## Zabbix agent on another host, passive mode
Next step, get a zabbix-agent on another host talking to this zabbix-server.  My first host is a Centos 7 VM located on my home server. Note that I have an existing Zabbix infrastructure already in place, so I am using 10070-71 for ports, not the defaults. This sets up an agent in passive mode; that is, the zabbix-sever polls the agent and thus the incoming ports need to be opened. The following commands are run on that VM.
```
# VM - 192.168.100.178 (home LAN, behind firewall)  #-root, $-docker user
# firewall-cmd --permanent --add-port=10070-10071/tcp
# firewall-cmd --reload
...
$ docker run --name zabbix-agent \
         -p 10070:10050 \
         -e ZBX_SERVER_HOST="linode2.kozik.net" \
         -e ZBX_SERVER_PORT="10070" \
         -d zabbix/zabbix-agent:centos-5.0-latest
$ docker logs -f zabbix-agent
$ curl http://ipecho.net/plain  # what IP address does this server NATs to in the Internet <Agent IP Addr>
```
### with Pre Shared Keys
Re-done but with a pre-shared key stored at /var/lib/zabbix/enc in the file zabbix_agentd.psk.  The same key needs to be put in the encryption tab of the host configuration. 
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
Next, go to the home router and open a NAT connection from the internet to 192.168.100.178:10070.  I don't show details of this here.  

Next, verify that the plumbing is setup correctly.  Go back to the zabbix server container.  
```
# Zabbix Server VM
$ docker exec -it zabbix-server-mysql /bin/bash
  $ zabbix_get -s<Agent IP Addr> -p 10070 -k system.hostname
```
### At Zabbix portal configure new passive host
From a web browser go to the zabbix web page: http://linode2.kozik.net. Login and go to the configuration for the Zabbix Server. Add a new host using the <Agent IP Addr> as the IP address and host name with port 10070.  Use templates: *Template OS Linux by Zabbix agent*.  Wait awhile and verify that the ZBX icon turns green. 
      
My zabbix-server was complaining about swap space size.  Here's what I did to fix the issue on my zabbix-server host root login.
```
# dd if=/dev/zero of=/newswap bs=1024 count=256000
# chmod 600 /newswap
# mkswap  /newswap
# swapon /newswap
# chmod 600 /newswap
# free -h
# vi /etc/fstab  # add "/newswap    swap    swap   defaults 0 0" at the bottom
```
## Zabbix agent on another host, active mode
On my home server install a zabbix-agent in active mode; that is, the zabbix-server waits for the agent to report to it.  No firewall ports need to be open. On my home LAN, this VM is 192.168.100.177. Running in a docker user account I did the following:
```
# VM - 192.168.100.177 Alpine Linux (home LAN, behind firewall)
$ docker run --name zabbix-agent -e ZBX_ACTIVESERVERS="linode2.kozik.net"  \
   -e ZBX_HOSTNAME="Alpine178" \
   -d zabbix/zabbix-agent:alpine-5.0-latest
$ 
$ docker logs -f zabbix-agent

```
From a web browser go to the zabbix web page: http://linode2.kozik.net. Login and go to the configuration for the Zabbix Server. Add a new host using the hostname as above (Alpine178) and the IP address of 0.0.0.0; you must select a template geared for active zabbix agents.  In this case, I selected the template "Template OS Linux by Zabbix agent active".    For me the ZBX icon didn't turn green, but I was seeing data collected right away.  

### Active Agent Autoregistration
Next, it is useful to verify that active agent autoregistration works.  First, on the zabbix-server, go to Configuration → Actions, select Autoregistration as the event source and click on Create action an action called "Linux Host Autoregistration" that registers the host and adds a "Template OS Linux by Zabbix agent active" template.  Also set it up to check for a preshared key in the HostMetaData field. See https://www.zabbix.com/documentation/current/manual/discovery/auto_registration

On the host (back on the VM 177), reinstall the zabbix-agent as follows:
```
# VM - 192.168.100.177 Alpine Linux (home LAN, behind firewall)
$ docker stop zabbix-agent;docker rm zabbix-agent
$ docker run --name zabbix-agent -e ZBX_ACTIVESERVERS="linode2.kozik.net" \
      -e ZBX_HOSTNAME="Alpine177" 
      -e ZBX_METADATA="Linux VM 71269fe72952ad5b56017c8aab3368191e283935756959e60f1047fc2cc2e6ad" \
      -d zabbix/zabbix-agent:alpine-5.0-latest
$ docker logs -f zabbix-agent
'''
On the zabbix-server host Alpine177 will appear shortly.


