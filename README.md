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
      -e PHP_TZ=America/Chicago \
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
$ #OLD docker run --name zabbix-agent --link zabbix-server-mysql:zabbix-server -d zabbix/zabbix-agent:centos-5.0-latest
$ docker run --name zabbix-agent 
    --link zabbix-server-mysql:zabbix-server \
    -e ZBX_HOSTNAME="Zabbix server" 
    -d zabbix/zabbix-agent:centos-5.0-latest
$ docker container inspect zabbix-agent | grep IPAddress  # Get the IP Address of the zabbix-agent
```
From a web browser go to the zabbix web page: http://linode2.kozik.net. Login with the default username/password and go to the configuration for the Zabbix Server.  Add a new host; set the hostname to "Zabbix server" (no quotes); for its interfaces/Agent field, enter the IP Address from above. Soon the ZBX icon should turn green.

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
```
On the zabbix-server host Alpine177 will appear shortly.

# Restart
Something I haven't figured out yet.  When my Linode VM running zabbix reboots, the zabbix containers do not cleanly restart.

Thus, I have to manually sequence the restarting of the zabbix containers, as follows.
```
$ docker ps
$ docker stop <any zabbix containers that might be running.
$ docker ps -a     # verify that all the zabbix containers are still there, but stopped
$ docker start mysql-server
$ docker start zabbix-java-gateway
$ docker start zabbix-server-mysql
$ docker start zabbix-web-apache-mysql
$ docker start zabbix-agent
$ docker ps # verify that all the zabbix containers are running.
```
Should I be doing this in systemd?

# Upgrade
My first upgrade was from 5.0 to 5.2.  I couldn't find any guides for doing this upgrade.  The release documentation only shows the steps when upgrading from a yum-based packagtes environment.  See link https://www.zabbix.com/documentation/current/manual/installation/upgrade/packages/rhel_centos

So I just followed what I thought was common sense docker best practice.  First I cloned my image.  I run my zabbix server on a Linode instance.  I ran the Linode "clone" procedure and created a backup image of everything.  Second, I stopped and deleted the key zabbix server containers:
```
$ docker stop zabbix-java-gateway zabbix-server-mysql zabbix-web-apache-mysql
$ docker rm zabbix-java-gateway zabbix-server-mysql zabbix-web-apache-mysql
```
Next I re-ran the docker run commands (noted above) but with a centos-5.2-latest tag.  Here's an abreviated version of the command lines
```
$ docker run --name zabbix-java-gateway ... -d zabbix/zabbix-java-gateway:centos-5.2-latest
$ docker run --name zabbix-server-mysql ... -d zabbix/zabbix-server-mysql:centos-5.2-latest
$ docker run --name zabbix-web-apache-mysql ... -d zabbix/zabbix-web-apache-mysql:centos-5.2-latest
```
I then went over to the zabbix web interface and everything worked.  It made me reenter my username/password.

Other things to do:  I need also to upgrade my proxy server and my agents.  

Note:  I did not touch the mysql container.  I left it running.  I did not move to the new version of mysql... not needed, and not easy.  

# Agent 2
I am trying to setup Zabbix Agent 2.  So far, running into issues with discovery of docker information.  Here's what I did to start:
```
$ docker run --name zabbix-agent \
    --link zabbix-server-mysql:zabbix-server \
    -e ZBX_HOSTNAME="Zabbix server" \
    --privileged\
    -d zabbix/zabbix-agent2:alpine-5.2-latest
```
My problem was the mysql container blew up with a 137 error.  Not sure how to fix.

# cAdvisor
To help me better troubleshoot my zabbix containers, I've installed cAdvisor.  I used the following run command that I found in the repository https://github.com/google/cadvisor/blob/master/docs/running.md
Note: I picked the run command for Centos.
```
docker run \
--volume=/:/rootfs:ro \
--volume=/var/run:/var/run:rw \
--volume=/sys/fs/cgroup/cpu,cpuacct:/sys/fs/cgroup/cpuacct,cpu \
--volume=/var/lib/docker/:/var/lib/docker:ro \
--publish=8080:8080 \
--detach=true \
--name=cadvisor \
--privileged=true \
google/cadvisor:latest
```
For my setup, I just accessed the link http://myzabbixserver.com:8080 and cAdvisor dashboard cameup, with no other setup required.
