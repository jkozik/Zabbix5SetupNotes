# Setup Zabbix Agent from Packages
## Alpine Linux
### Active Agent w/PSK
Reference https://wiki.alpinelinux.org/wiki/Setting_up_Zabbix
```
# vi /etc/groups    # edit to include zabbix "readproc:x:30:zabbix"
# apk add zabbix-agent curl
# cat >> /etc/zabbix/zabbix_agentd.conf <<EOL
ServerActive=linode2.kozik.net
Hostname=Alpine177
HostMetadata=Linux VM 71269fe72952ad5b56017c8aab3368191e283935756959e60f1047fc2cc2e6ad
EOL

# rc-update add zabbix-agentd
# /etc/init.d/zabbix-agentd start
# netstat -lntp
# service zabbix-agentd restart
# tail -f /var/log/zabbix/zabbix_agentd.log
```
I had troubles where a syntax error in my zabbix_agentd.conf silently failed.  I had to run the zabbix_agentd in command line mode to find the error.
On the zabbix server, the host Alpine auto registers nicely.  After a few minutes, the agent sends data to the server and displays nicely.

### Passive Agent w/PSK
1-First shut off the zabbix-agent.
```
# service zabbix-agentd stop
```
2-Remove host Alpine177. Go to the zabbix web page http://linode2.kozik.net and remove the host Alpine177. (Configuration->Hosts->Alpine177, Delete) 
3-Reconfigure agent for passive. Assume zabbix-agent is already installed.  Go into /etc/zabbix/zabbix_agentd.conf, clean out the parameters that were appended for last step. And append a new set of parameters.
```
# vi /etc/zabbix/zabbix_agentd.conf     # clear out the old parameters at the tail of the file
# cat >> /etc/zabbix/zabbix_agentd.conf <<EOL
Server=linode2.kozik.net
ListenPort=10080      
TLSConnect=psk
TLSAccept=psk
TLSPSKIdentity=PSK 001
TLSPSKFile=/etc/zabbix/zabbix_agentd.psk
EOL
# cat >> /etc/zabbix/zabbix_agentd.psk <<EOL
71269fe72952ad5b56017c8aab3368191e283935756959e60f1047fc2cc2e6ad
EOL
# service zabbix-agentd restart
# curl http://ipecho.net/plain    # This is the IP Address on the other side of our home LAN NAT.  <IP Addr>
```
4-Add host Alpine 177. Unlike the active agent, passive agents must be manually added into the zabbix-server.  Surf to http://linode2.kozik.net, Configuration->Hosts->Create Hosts. 
```
Hostname-Alpine177 
IP-<IP Addr>
Port-10080     # in my case, I already have zabbix installed, and am using non 10050 ports for setup and testing
```
5-Last step, go into the home router and setup a NAT between <IP Addr> and zabbix-agent's IP address, port 10080:10080. 
6-Verify.  The log files on the zabbix-server and zabbix-agent should be checked.  In a few minutes the ZBX icon next to the Alpine177 host on zabbix-server should turn green.


## Centos 7 Agent Setup
Reference https://tecadmin.net/install-zabbix-agent-on-centos-rhel/
### Active Agent w/PSK
```
# rpm -Uvh https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-2.el7.noarch.rpm
# yum install zabbix-agent
# cat >> /etc/zabbix/zabbix_agentd.conf <<EOL
ServerActive=linode2.kozik.net
Hostname=Centos7-178
HostMetadata=Linux VM 71269fe72952ad5b56017c8aab3368191e283935756959e60f1047fc2cc2e6ad
EOL
# systemctl start zabbix-agent
# systemctl enable zabbix-agent
# systemctl status zabbix-agent      # Verify 
# netstat -lntp     # Verify
```




