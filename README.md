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
#### update on swap
For linode 4, I did the swap a little differently:
```
[root@linode4 ~]# free -m
              total        used        free      shared  buff/cache   available
Mem:           1837        1115          68         128         653         428
Swap:             0           0           0
[root@linode4 ~]# fallocate -l 2G /swapfile
[root@linode4 ~]# ls -lasth  /
total 2.1G
2.1G -rw-------.   1 root root 2.0G Nov  1 18:34 swapfile
...
[root@linode4 ~]# mkswap /swapfile
Setting up swapspace version 1, size = 2097148 KiB
no label, UUID=294c18ca-9e42-4d84-9703-6731411cca8a
[root@linode4 ~]# swapon /swapfile
[root@linode4 ~]# free-m
-bash: free-m: command not found
[root@linode4 ~]# free -m
              total        used        free      shared  buff/cache   available
Mem:           1837        1116          69         128         651         426
Swap:          2047           0        2047
[root@linode4 ~]# vi /etc/fstab    # add "/swapfile    swap    swap   defaults 0 0"
[root@linode4 ~]# free -h
              total        used        free      shared  buff/cache   available
Mem:           1.8G        1.1G         67M        127M        652M        426M
Swap:          2.0G        768K        2.0G
[root@linode4 ~]# swapon -s
Filename                                Type            Size    Used    Priority
/swapfile                               file    2097148 768     -2
[root@linode4 ~]# grep SwapTotal /proc/meminfo
SwapTotal:       2097148 kB
[root@linode4 ~]#
```
The following references helped:
[Fixing Lack of Free Swap Space Error on Zabbix Server 4.2](https://youtube.com/watch?v=7QTN8DoT1aU)
[How to increase the size of your swapfile](https://arcolinux.com/how-to-increase-the-size-of-your-swapfile/)
[Create a Linux Swap File](https://linuxize.com/post/create-a-linux-swap-file/)




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
# Upgrade Zabbix 5.2 to 6.0 Setup Notes
Just to be safe, I upgraded to 6.0 my setting a new VM on linode.  linode3.kozik.net. I started a new VM running Centos7 and installed Zabbix 6 on it using docker. 
The upgrade process is simple:  
1. from the old VM copy the mysql database for 5.2 to the new VM
2. spin up mysql on the new VM and import the database
3. launch the Zabbix 6.0 containers 
4. review the log files to confirm the database was evolved to 6.0
This just follows the [zabbix installation instructions for containers](https://www.zabbix.com/documentation/current/en/manual/installation/containers#examples)
## Old VM.  Export Zabbix 5.2 database. Copy to new VM
```
[jkozik@linode2 ~]$ docker exec mysql-server /usr/bin/mysqldump -u zabbix  -pzabbix_pwd --all-databases --quick  > zabbix54_072523.sql
mysqldump: [Warning] Using a password on the command line interface can be insecure.

[jkozik@linode2 ~]$ ls -last
total 499124
498984 -rw-rw-r--.  1 jkozik jkozik 510958698 Aug 11 22:44 zabbix54_072523.sql

[jkozik@linode2 ~]$ scp zabbix54_072523.sql  linode3.kozik.net:~jkozik/54.dmp
jkozik@linode3.kozik.net's password:
zabbix54_072523.sql                                                                                               100%  487MB  51.7MB/s   00:09
[jkozik@linode2 ~]$
```
## New VM. Import Zabbix 5.2 database into new mysql container
```
docker volume create mysqldb
docker volume ls
docker network create --subnet 172.20.0.0/16 --ip-range 172.20.240.0/20 zabbix-net
docker network ls

docker run --name mysql-server -t \
      -e MYSQL_DATABASE="zabbix" \
      -e MYSQL_USER="zabbix" \
      -e MYSQL_PASSWORD="zabbix_pwd" \
      -e MYSQL_ROOT_PASSWORD="root_pwd" \
      -v mysqldb:/var/lib/mysql \
      --network=zabbix-net \
      --restart unless-stopped \
      -d mysql:8.0.34 \
      --character-set-server=utf8 --collation-server=utf8_bin \
      --default-authentication-plugin=mysql_native_password

$ docker cp zabbix54_072523.sql mysql-server:/tmp
Successfully copied 648MB to mysql-server:/tmp
$ docker exec -it mysql-server /bin/bash
bash-4.4# cd /tmp
bash-4.4# ls
zabbix54_072523.sql
bash-4.4# exit
exit

$ docker exec -it mysql-server /bin/bash
bash-4.4# mysql -uzabbix -p
Enter password:
Welcome to the MySQL monitor.  Commands end with ; or \g.
mysql> source /tmp/zabbix54_072523.sql
Query OK, 0 rows affected (0.00 sec)

mysql> show databases
    -> ;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| performance_schema |
| zabbix             |
+--------------------+
3 rows in set (0.02 sec)

mysql> use information_schema
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
mysql> show tables
    -> ;
+---------------------------------------+
| Tables_in_information_schema          |
+---------------------------------------+
| ADMINISTRABLE_ROLE_AUTHORIZATIONS     |
| APPLICABLE_ROLES                      |


mysql> describe views;
+----------------------+---------------------------------+------+-----+---------+-------+
| Field                | Type                            | Null | Key | Default | Extra |
+----------------------+---------------------------------+------+-----+---------+-------+
| TABLE_CATALOG        | varchar(64)                     | NO   |     | NULL    |       |
| TABLE_SCHEMA         | varchar(64)                     | NO   |     | NULL    |       |
| TABLE_NAME           | varchar(64)                     | NO   |     | NULL    |       |
| VIEW_DEFINITION      | longtext                        | YES  |     | NULL    |       |
| CHECK_OPTION         | enum('NONE','LOCAL','CASCADED') | YES  |     | NULL    |       |
| IS_UPDATABLE         | enum('NO','YES')                | YES  |     | NULL    |       |
| DEFINER              | varchar(288)                    | YES  |     | NULL    |       |
| SECURITY_TYPE        | varchar(7)                      | YES  |     | NULL    |       |
| CHARACTER_SET_CLIENT | varchar(64)                     | NO   |     | NULL    |       |
| COLLATION_CONNECTION | varchar(64)                     | NO   |     | NULL    |       |
+----------------------+---------------------------------+------+-----+---------+-------+
10 rows in set (0.01 sec)

mysql> exit

$ docker volume inspect mysqldb
[
    {
        "CreatedAt": "2023-07-26T02:23:57Z",
        "Driver": "local",
        "Labels": null,
        "Mountpoint": "/var/lib/docker/volumes/mysqldb/_data",
        "Name": "mysqldb",
        "Options": null,
        "Scope": "local"
    }

docker logs -f mysql-server

```
Note: I created a docker volume to store the mysql data.  This way the data will persist if mysql needs to be upgraded. I copied the exported data from the old VM into the new containers, and then I logged into mysql and imported the data using the source command.  I show and describe command to verify the basic structure is correct. This data is still in 5.x format.  When 6.0 starts, it will notice that and evolve the data forward.

Also note from the [installation instructions,](https://www.zabbix.com/documentation/current/en/manual/appendix/install/db_scripts#mysql)a global variable needs to be set before importing the zabbix database.
```
[jkozik@linode3 ~]$ docker exec -it mysql-server /bin/bash
bash-4.4# mysql -uroot -proot_pwd
mysql: [Warning] Using a password on the command line interface can be insecure.
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 280267
Server version: 8.0.34 MySQL Community Server - GPL

Copyright (c) 2000, 2023, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> SET GLOBAL log_bin_trust_function_creators = 1;
Query OK, 0 rows affected, 1 warning (0.00 sec)

mysql> quit
Bye
bash-4.4# exit
exit
```

## Create zabbix containers: zabbix-java-gateway, zabbix-server-mysql, zabbix-web-nginx-mysql
Following the [zabbix installation instructions for containers](https://www.zabbix.com/documentation/current/en/manual/installation/containers#examples), create the zabbix containers.
```
docker run --name zabbix-java-gateway -t \
      --restart unless-stopped \
      --network=zabbix-net \
      -d zabbix/zabbix-java-gateway:alpine-6.0-latest


docker run --name zabbix-server-mysql -t \
      -e DB_SERVER_HOST="mysql-server" \
      -e MYSQL_DATABASE="zabbix" \
      -e MYSQL_USER="zabbix" \
      -e MYSQL_PASSWORD="zabbix_pwd" \
      -e MYSQL_ROOT_PASSWORD="root_pwd" \
      -e ZBX_JAVAGATEWAY="zabbix-java-gateway" \
      -e PHP_TZ=America/Chicago \
      -p 10051:10051 \
      --restart unless-stopped \
      --network=zabbix-net \
      -d zabbix/zabbix-server-mysql:alpine-6.0-latest

docker logs zabbix-server-mysql


docker run --name zabbix-web-nginx-mysql -t \
      -e ZBX_SERVER_HOST="zabbix-server-mysql" \
      -e DB_SERVER_HOST="mysql-server" \
      -e MYSQL_DATABASE="zabbix" \
      -e MYSQL_USER="zabbix" \
      -e MYSQL_PASSWORD="zabbix_pwd" \
      -e MYSQL_ROOT_PASSWORD="root_pwd" \
      --network=zabbix-net \
      -p 80:8080 \
      --restart unless-stopped \
      -d zabbix/zabbix-web-nginx-mysql:alpine-6.0-latest


docker logs zabbix-web-nginx-mysql
```
It is important to verify that the zabbix-server-mysql log files show a successful evolve of the database to the 6.0 schema. 
## Zabbix agent on zabbix server
And finally on the same VM as the Zabbix server, install a zabbix agent to monitor the health of the server. 
```
docker run --name zabbix-agent -t \
    --link zabbix-server-mysql:zabbix-server \
    --network=zabbix-net \
    --restart unless-stopped \
    -e ZBX_HOSTNAME="Zabbix server" \
    -d zabbix/zabbix-agent:centos-6.0-latest

[jkozik@linode3 ~]$ docker container inspect zabbix-agent | grep IPAddress  # Get the IP Address of the zabbix-agent
            "SecondaryIPAddresses": null,
            "IPAddress": "",
                    "IPAddress": "172.20.240.5",
[jkozik@linode3 ~]$

```
Note: In the Zabbix web client, the IP address of the Zabbix server is found with the inspection command, see above.

## Troubleshooting tools: zabbix_get and tcpdump
The docker container for the zabbix agent bundles zabbix_get.  Here's an example of querying a host with a pre-shared key from the zabbix server's agent container.
```
[jkozik@linode3 bin]$ docker exec -it zabbix-agent /bin/bash
bash-4.4$ zabbix_get -s 73.73.67.228 -p 10060 -k system.hostname --tls-connect psk  --tls-psk-identity "PSK 001" --tls-psk-file /var/lib/zabbix/zabbix.psk
dell1.kozik.net

bash-4.4$ zabbix_get -s 73.73.67.228 -p 10060 -k system.sw.os --tls-connect psk  --tls-psk-identity "PSK 001" --tls-psk-file /var/lib/zabbix/zabbix.
psk
Linux version 3.10.0-1160.36.2.el7.x86_64 (mockbuild@kbuilder.bsys.centos.org) (gcc version 4.8.5 20150623 (Red Hat 4.8.5-44) (GCC) ) #1 SMP Wed Jul 21 11:57:15 UTC 2021
bash-4.4$
```
Also, from the root account it is useful to look at the raw traffic from a host to the zabbix server using the tcpdump tool.
```
[root@linode3 ~]# tcpdump -ieth0 host dell1.kozik.net and port 10060 -c10 -nn
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
19:01:58.072588 IP 172.232.13.192.46982 > 73.73.67.228.10060: Flags [S], seq 2584394634, win 29200, options [mss 1460,sackOK,TS val 1607147931 ecr 0,nop,wscale 7], length 0
19:01:58.083673 IP 73.73.67.228.10060 > 172.232.13.192.46982: Flags [S.], seq 2647721261, ack 2584394635, win 28960, options [mss 1460,sackOK,TS val 3895631272 ecr 1607147931,nop,wscale 7], length 0
19:01:58.083712 IP 172.232.13.192.46982 > 73.73.67.228.10060: Flags [.], ack 1, win 229, options [nop,nop,TS val 1607147942 ecr 3895631272], length 0
19:01:58.084090 IP 172.232.13.192.46982 > 73.73.67.228.10060: Flags [P.], seq 1:347, ack 1, win 229, options [nop,nop,TS val 1607147943 ecr 3895631272], length 346
19:01:58.095276 IP 73.73.67.228.10060 > 172.232.13.192.46982: Flags [.], ack 347, win 235, options [nop,nop,TS val 3895631283 ecr 1607147943], length 0
19:01:58.099949 IP 73.73.67.228.10060 > 172.232.13.192.46982: Flags [P.], seq 1:64, ack 347, win 235, options [nop,nop,TS val 3895631283 ecr 1607147943], length 63
19:01:58.100086 IP 172.232.13.192.46982 > 73.73.67.228.10060: Flags [.], ack 64, win 229, options [nop,nop,TS val 1607147959 ecr 3895631283], length 0
19:01:58.100474 IP 172.232.13.192.46982 > 73.73.67.228.10060: Flags [P.], seq 347:440, ack 64, win 229, options [nop,nop,TS val 1607147959 ecr 3895631283], length 93
19:01:58.115721 IP 73.73.67.228.10060 > 172.232.13.192.46982: Flags [P.], seq 64:139, ack 440, win 235, options [nop,nop,TS val 3895631300 ecr 1607147959], length 75
19:01:58.115958 IP 172.232.13.192.46982 > 73.73.67.228.10060: Flags [P.], seq 440:509, ack 139, win 229, options [nop,nop,TS val 1607147975 ecr 3895631300], length 69
10 packets captured
15 packets received by filter
0 packets dropped by kernel
[root@linode3 ~]#
```

