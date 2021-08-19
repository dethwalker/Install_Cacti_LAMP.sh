#!/bin/bash

dnf -y install epel-release

#----- User Input -----
read -p "IP address of this server: " SERVER_IPADDR
read -p "Enter the network this server is in: " SERVER_NETWORK
read -p "CIDR Subnet mask: " SERVER_SUBNET
read -p "Enter server name for Apache(If left blank then the IP of this server will be used): " SERVER_NAME
read -s -p "MariaDB root user password: " MYSQL_ROOT_PW
printf "\n"
read -s -p "MariaDB cacti user password: " MYSQL_CACTI_PW
printf "\n"
read -p "Community string: " COMM_STRING

if [[ -z $SERVER_NAME ]]; then
	SERVER_NAME=$SERVER_IPADDR
	printf "Server name will be %s\n" "$SERVER_NAME"
fi

CURRENT_TIMEZONE=$(timedatectl | grep "Time zone" | cut -d':' -f 2 | cut -d' ' -f 2)
printf "Timezone is %s\n" "$CURRENT_TIMEZONE"

#----- Apache -----
printf "Installing Apache\n"

dnf -y install httpd

mv /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.d/welcome.conf.orig

sed -i "98 s/.*/ServerName ${SERVER_NAME}:80/" /etc/httpd/conf/httpd.conf
sed -i "147 s/Indexes.//" /etc/httpd/conf/httpd.conf
sed -i "154 s/None/All/" /etc/httpd/conf/httpd.conf
sed -i "167 s/DirectoryIndex.*/DirectoryIndex index.html index.php index.cgi/" /etc/httpd/conf/httpd.conf
echo "ServerSignature Off" >> /etc/httpd/conf/httpd.conf
echo "ServerTokens Prod" >> /etc/httpd/conf/httpd.conf

systemctl enable --now httpd

firewall-cmd --add-service=http --permanent
firewall-cmd --reload

#----- PHP -----
printf "Installing PHP\n"

dnf module -y reset php
dnf module -y enable php:7.4
dnf module -y install php:7.4/common

#----- MariaDB -----
printf "Installing MariaDB\n"

dnf module -y install mariadb:10.3

touch /etc/my.cnf.d/charset.cnf
echo -e "[mysqld]" > /etc/my.cnf.d/charset.cnf
echo -e "character-set-server = utf8mb4" >> /etc/my.cnf.d/charset.cnf
echo -e "\n[client]" >> /etc/my.cnf.d/charset.cnf
echo -e "default-character-set = utf8mb4" >> /etc/my.cnf.d/charset.cnf

systemctl enable --now mariadb

dnf -y install expect

SECURE_MYSQL=$(expect -c "
set timeout 5
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Set root password? \"
send \"y\r\"
expect \"New password: \"
send \"$MYSQL_ROOT_PW\r\"
expect \"Re-enter new password: \"
send \"$MYSQL_ROOT_PW\r\"
expect \"Remove anonymous users?  \"
send \"y\r\"
expect \"Disallow root login remotely? \"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now? \"
send \"y\r\"
expect eof
")

echo "$SECURE_MYSQL"


#----- Cacti -----
printf "Installing Cacti\n"
dnf -y install cacti net-snmp net-snmp-utils php-mysqlnd php-snmp php-bcmath rrdtool


printf "Configuring snmpd\n"
sed -i "41 s/^com/#com/" /etc/snmp/snmpd.conf
sed -i "74 s/COMMUNITY/$COMM_STRING/" /etc/snmp/snmpd.conf
sed -i "74 s/^#//" /etc/snmp/snmpd.conf
sed -i "75 s/^#//" /etc/snmp/snmpd.conf
sed -i "75 s/NETWORK/$SERVER_IPADDR/" /etc/snmp/snmpd.conf
sed -i "75 s/24/$SERVER_SUBNET/" /etc/snmp/snmpd.conf
sed -i "75 s/COMMUNITY/$COMM_STRING/" /etc/snmp/snmpd.conf
sed -i "78 s/any/v2c/" /etc/snmp/snmpd.conf
sed -i "79 s/any/v2c/" /etc/snmp/snmpd.conf
sed -i "78 s/^#//" /etc/snmp/snmpd.conf
sed -i "79 s/^#//" /etc/snmp/snmpd.conf
sed -i "85 s/^#//" /etc/snmp/snmpd.conf
sed -i "93 s/any/v2c/" /etc/snmp/snmpd.conf
sed -i "94 s/any/v2c/" /etc/snmp/snmpd.conf
sed -i "93 s/^#//" /etc/snmp/snmpd.conf
sed -i "94 s/^#//" /etc/snmp/snmpd.conf
sed -i "93 s/0/exact/" /etc/snmp/snmpd.conf
sed -i "94 s/0/exact/" /etc/snmp/snmpd.conf

systemctl enable --now snmpd


#----- MariaDB Config -----

printf "Configuring MariaDB for Cacti\n"
sed -i "21 a default-time-zone=\'$CURRENT_TIMEZONE\'" /etc/my.cnf.d/mariadb-server.cnf
sed -i "22 a character-set-server=utf8mb4" /etc/my.cnf.d/mariadb-server.cnf
sed -i "23 a character_set_client=utf8mb4" /etc/my.cnf.d/mariadb-server.cnf
sed -i "24 a collation-server=utf8mb4_unicode_ci" /etc/my.cnf.d/mariadb-server.cnf
sed -i "25 a max_heap_table_size=128M" /etc/my.cnf.d/mariadb-server.cnf
sed -i "26 a tmp_table_size=128M" /etc/my.cnf.d/mariadb-server.cnf
sed -i "27 a join_buffer_size=256M" /etc/my.cnf.d/mariadb-server.cnf
sed -i "28 a innodb_file_format=Barracuda" /etc/my.cnf.d/mariadb-server.cnf
sed -i "29 a innodb_large_prefix=1" /etc/my.cnf.d/mariadb-server.cnf
sed -i "30 a innodb_buffer_pool_size=2048M" /etc/my.cnf.d/mariadb-server.cnf
sed -i "31 a innodb_flush_log_at_timeout=3" /etc/my.cnf.d/mariadb-server.cnf
sed -i "32 a innodb_read_io_threads=32" /etc/my.cnf.d/mariadb-server.cnf
sed -i "33 a innodb_write_io_threads=16" /etc/my.cnf.d/mariadb-server.cnf
sed -i "34 a innodb_buffer_pool_instances=17" /etc/my.cnf.d/mariadb-server.cnf
sed -i "35 a innodb_io_capacity=5000" /etc/my.cnf.d/mariadb-server.cnf
sed -i "36 a innodb_io_capacity_max=10000" /etc/my.cnf.d/mariadb-server.cnf

mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root --password=$MYSQL_ROOT_PW mysql

systemctl restart mariadb

mysql -u root --password=$MYSQL_ROOT_PW -e "create database cacti;"
mysql -u root --password=$MYSQL_ROOT_PW -e "grant all privileges on cacti.* to cacti@'localhost' identified by '${MYSQL_CACTI_PW}';"
mysql -u root --password=$MYSQL_ROOT_PW -e "grant select on mysql.time_zone_name to cacti@'localhost';"
mysql -u root --password=$MYSQL_ROOT_PW -e "flush privileges;"

mysql -u cacti --password=$MYSQL_CACTI_PW cacti < /usr/share/doc/cacti/cacti.sql


#----- SELinux -----

printf "Creating SELinux policy\n"

setsebool -P httpd_can_network_connect on
setsebool -P httpd_unified on
setsebool -P domain_can_mmap_files on

touch cacti-phpfpm.te

echo -e "module cacti-phpfpm 1.0;\n" > cacti-phpfpm.te
echo -e "require {" >> cacti-phpfpm.te
echo -e "\ttype admin_home_t;" >> cacti-phpfpm.te
echo -e "\ttype httpd_t;" >> cacti-phpfpm.te
echo -e "\ttype httpd_log_t;" >> cacti-phpfpm.te
echo -e "\tclass file { getattr map open read unlink write };" >> cacti-phpfpm.te
echo -e "\tclass dir { remove_name };" >> cacti-phpfpm.te
echo -e "}\n" >> cacti-phpfpm.te
echo -e "#============= httpd_t ==============" >> cacti-phpfpm.te
echo -e "allow httpd_t admin_home_t:file map;" >> cacti-phpfpm.te
echo -e "allow httpd_t admin_home_t:file { getattr open read };" >> cacti-phpfpm.te
echo -e "allow httpd_t httpd_log_t:dir remove_name;" >> cacti-phpfpm.te
echo -e "allow httpd_t httpd_log_t:file { unlink write };" >> cacti-phpfpm.te

checkmodule -m -M -o cacti-phpfpm.mod cacti-phpfpm.te
semodule_package --outfile cacti-phpfpm.pp --module cacti-phpfpm.mod
semodule -i cacti-phpfpm.pp


#----- Final Configs -----

printf "Final configuraions\n"

printf "Configuring cron\n"
sed -i "1 s/^#//" /etc/cron.d/cacti

printf "Configuring config.php\n"
sed -i "32 s/cactiuser/cacti/" /usr/share/cacti/include/config.php
sed -i "33 s/cactiuser/$MYSQL_CACTI_PW/" /usr/share/cacti/include/config.php

printf "Configuring php.ini\n"
sed -i "388 s/30/60/" /etc/php.ini
sed -i "409 s/128/512/" /etc/php.ini
sed -i "923 a date.timezone = ${CURRENT_TIMEZONE}" /etc/php.ini

printf "Configuring cacti.conf\n"
sed -i "17 s/localhost/localhost\n\t\tRequire ip $SERVER_NETWORK\/$SERVER_SUBNET/" /etc/httpd/conf.d/cacti.conf


systemctl restart httpd php-fpm

printf "Done!\nPlease visit http://%s/cacti/ for Cacti configuration.\n" "${SERVER_IPADDR}"
