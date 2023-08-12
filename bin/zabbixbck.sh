NOW=$(date +"%Y-%m-%d")
CONFIG_DIR="/etc"
LOGS_DIR="/var/log/zabbix"
BACKUP_DIR="/tmp/zabbix_backups"
ZABBIX_DB="zabbix"

echo "Backing up database. This may take a while..."
docker exec mysql-server /usr/bin/mysqldump -u root  -proot_pwd --all-databases --quick > $BACKUP_DIR/$ZABBIX_DB.sql.dmp

echo "Backing up configs..."
mkdir -p $BACKUP_DIR/etc
docker exec -it zabbix-server-mysql cat /etc/zabbix/zabbix_server.conf > $BACKUP_DIR/etc/zabbix_server.conf

echo "Creating backup file..."
mkdir -p ~jkozik/backup
FILE="/home/jkozik/backup/zabbix_backup-$NOW.tar.gz"
tar -zcvf $FILE /tmp/zabbix_backups

rsync -av -e "ssh -i /home/jkozik/.ssh/id_rsa -p 2200" $FILE rsync@synology.kozik.net::NetBackup/linode3


#rm $BACKUP_DIR/$ZABBIX_DB.sql.dmp
